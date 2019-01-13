require 'logger'
require 'shex-map'
require 'rdf/turtle'

class Thumb < Struct.new(:graph, :subject)
  def value_at(predicate)
    graph.query([subject, predicate, nil]).first.object
  end

  def walk(predicate)
    Thumb.new(graph, graph.query([subject, predicate, nil]).first.object)
  rescue
    fail "No statement matches [#{subject}, #{predicate}, nil]"
  end

  def statements_about
    graph.query([subject, nil, nil]).to_a
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
  mf = RDF::Vocabulary.new("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#")
  t = RDF::Vocabulary.new("https://raw.githubusercontent.com/shexSpec/shexmapTest/master/testcase.ttl#")


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


  shared_examples "round trip" do |testcase, config|
    include_context "common configuration"

    let(:left_shex_path) do
      config.walk(t[:left]).value_at(t[:source]).to_s
    end
    let(:left_shape) do
      config.walk(t[:left]).value_at(t[:shape])
    end

    let(:right_shex_path) do
      config.walk(t[:right]).value_at(t[:source]).to_s
    end
    let(:right_shape) do
      config.walk(t[:right]).value_at(t[:shape])
    end

    let(:input_graph_path) do
      config.walk(t[:start]).value_at(t[:source]).to_s
    end
    let(:start_iri) do
      config.walk(t[:start]).value_at(t[:focus])
    end

    let(:expected_graph_path) do
      config.walk(t[:target]).value_at(t[:source]).to_s
    end
    let(:target_iri) do
      config.walk(t[:target]).value_at(t[:focus])
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
      end

      specify ".generate_from" do
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        expect(output).not_to be_nil
        expect(output).to have_same_statements_as(expected_graph)
      rescue ShEx::NotSatisfied => sns
        pp sns
        fail(sns)
      end

      it "should validate against right shex" do
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        right_shex.execute(output, {target_iri => right_shape})
      rescue ShEx::NotSatisfied => sns
        pp sns
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
        pp sns
        fail(sns)
      end
    end
  end

  testcases = RDF::Graph.new

  RDF::Reader.open('testcases/manifest.ttl', base_uri: "./testcases/") do |r|
    r.each_statement do |stmt|
      testcases.insert(stmt)
    end
  end

  entries = testcases.query([RDF::URI.new("./testcases/"), mf[:entries], nil]).first.object
  entries = RDF::List.new(graph: testcases, subject: entries)
  entries.each do |entry|
    thumb = Thumb.new(testcases, entry)
    next if thumb.value_at(mf[:result]) == mf[:rejected]
    action = thumb.walk(mf[:action])
    case action.value_at(t[:kind])
    when t[:RoundTrip]
      it_should_behave_like "round trip", thumb.value_at(mf[:name]).to_s, thumb.walk(mf[:action])
    else
      puts "Unknown kind of test: #{t[:kind]}"
    end
  end
end
