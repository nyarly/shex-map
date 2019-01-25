require 'logger'
require 'shex-map'
require 'rdf/turtle'

class FixedShapeMap < Struct.new(:node, :shape)
  RE = %r{<(?<node>[^>]+)>@<(?<shape>[^>]+)>}
  def self.parse(string)
    # small subset of the complete grammar
    m = RE.match(string)
    raise "Invalid map: #{string}" if m.nil?
    return new(m[:node], m[:shape])
  end
end

RSpec::Matchers.define :have_same_statements_as do |expected|
  def as_triples(graph)
    RDF::Writer.for(:ntriples).buffer do |w|
      graph.each_statement do |s|
        w << s
      end
    end
  end

  def equiv_statement(left, right)
    if left.subject != right.subject
      return false unless left.subject.is_a? RDF::Node
      return false unless right.subject.is_a? RDF::Node
    end

    if left.predicate != right.predicate
      return false unless left.predicate.is_a? RDF::Node
      return false unless right.predicate.is_a? RDF::Node
    end

    if left.object != right.object
      return false unless left.object.is_a? RDF::Node
      return false unless right.object.is_a? RDF::Node
    end
    return true
  end

  match do |actual|
    actual_stmts = actual.statements.clone
    expected_stmts = expected.statements

    unless actual_stmts.length == expected_stmts.length
      return false
    end
    expected_stmts.each do |es|
      i = actual_stmts.index{|as| equiv_statement(as, es)}
      return false if i.nil?
      actual_stmts.delete_at(i)
    end
    true
  end

  failure_message do |actual|
    "Expected graphs to be equivalent:\nActual:\n#{as_triples(actual)}Expected:\n#{as_triples(expected)}\n"
  end
end

describe ShExMap do
  shared_context "common configuration" do
    let(:map_iri) { RDF::URI.new("http://shex.io/extensions/Map/") }
    let(:prefixes) do
      {
        nil => RDF::URI.new("http://example/"),
        ex: RDF::URI.new("http://example/"),
        xsd: RDF::URI.new("http://www.w3.org/2001/XMLSchema#"),
        map: map_iri
      }
    end

    let(:parse_options) do
      {
        validate: true,
        debug: true,
        progress: true,
        prefixes: prefixes
      }
    end

    def dump_graph(graph)
      puts (RDF::Writer.for(:ntriples).buffer do |w|
        graph.each_statement do |s|
          w << s
        end
      end)
    end

    def load_turtle(path)
      g = RDF::Graph.new
      RDF::Turtle::Reader.open(path, prefixes: prefixes) do |r|
        r.each_statement do |stmt|
          g.insert(stmt)
        end
      end
      g
    end
  end


  shared_examples "round trip" do |testcase, basepath, config|
    include_context "common configuration"

    let(:left_shex_path) do
      File.join(basepath, config['schemaURL'])
    end
    let(:left_shape) do
      RDF::URI.new(FixedShapeMap.parse(config['queryMap']).shape)
    end

    let(:right_shex_path) do
      File.join(basepath, config['shexMapTo']['schemaURL'])
    end
    let(:right_shape) do
      RDF::URI.new(FixedShapeMap.parse(config['shexMapTo']['queryMap']).shape)
    end

    let(:input_graph_path) do
      File.join(basepath, config['dataURL'])
    end
    let(:start_iri) do
      RDF::URI.new(FixedShapeMap.parse(config['queryMap']).node)
    end

    let(:expected_graph_path) do
      File.join(basepath, config['shexMapTo']['dataURL'])
    end
    let(:target_iri) do
      RDF::URI.new(FixedShapeMap.parse(config['shexMapTo']['queryMap']).node)
    end

    let(:input_graph) do
      load_turtle(input_graph_path)
    end

    let(:expected_graph) do
      load_turtle(expected_graph_path)
    end

    let(:left_shex) { ShEx.parse(File.read(left_shex_path), **parse_options) }
    let(:right_shex) { ShEx.parse(File.read(right_shex_path), **parse_options) }

    context testcase do
      before do
        left_shex.execute(input_graph, {start_iri => left_shape})
      rescue ShEx::NotSatisfied => sns
        dump_graph(input_graph)
        pp "execute left", [left_shex_path, input_graph_path, {start_iri => left_shape}], sns
        fail(sns)
      end

      specify ".generate_from" do
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        expect(output).not_to be_nil
        expect(output).to have_same_statements_as(expected_graph)
      end

      it "should validate against right shex" do
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        right_shex.execute(output, {target_iri => right_shape})
      rescue ShEx::NotSatisfied => sns
        dump_graph(output)
        pp "validating right", [left_shex_path, input_graph_path, {start_iri => left_shape}], sns
        fail(sns)
      end

      # We _don't_ expect maps to be entirely bi-directional, but after one
      # "pass" the resulting graphs should be.

      it "should be a well-behaved lens" do
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        right_shex.execute(output, {target_iri => right_shape})
        roundtrip = ShExMap.generate_from(right_shex, left_shex, {start_iri => left_shape})
        left_shex.execute(roundtrip, {start_iri => left_shape})
        second_output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        expect(second_output).to have_same_statements_as(expected_graph)
      rescue ShEx::NotSatisfied => sns
        dump_graph(roundtrip)
        pp "return left", [left_shex_path, input_graph_path, {start_iri => left_shape}], sns
        fail(sns)
      end
    end
  end

  entries = File::open('testcases/manifest.json') do |tc|
    JSON.parse(tc.read)
  end

  entries.each do |entry|
    it_should_behave_like "round trip", entry['schemaLabel'], './testcases', entry
  end
end
