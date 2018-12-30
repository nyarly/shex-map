require 'shex-map'
require 'rdf/turtle'

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
    let(:start_iri) { RDF::URI.new("http://example/foo") }
    let(:target_iri) { RDF::URI.new("http://example/bar") }
    let(:left_shape) { RDF::URI.new("http://a.example/S1") }
    let(:right_shape) { RDF::URI.new("http://b.example/S1") }

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


  shared_examples "shex-map" do |testcase|
    include_context "common configuration"

    let(:testcase_directory) do
      Pathname.new("testcases").join(testcase)
    end
    let(:left_shex_path) do
      testcase_directory.join("left.shex")
    end
    let(:right_shex_path) do
      testcase_directory.join("right.shex")
    end
    let(:input_graph_path) do
      testcase_directory.join("input.ttl")
    end
    let(:expected_graph_path) do
      testcase_directory.join("expected.ttl")
    end

    let(:input_graph) do
      load_turtle(input_graph_path)
    end

    let(:expected_graph) do
      load_turtle(expected_graph_path)
    end

    let(:left_shex) { ShEx.parse(File.read(left_shex_path), **parse_options) }
    let(:right_shex) { ShEx.parse(File.read(right_shex_path), **parse_options) }

    context "loading testcases from 'testcases/#{testcase}'" do
      specify ".generate_from" do
        left_shex.execute(input_graph, {start_iri => left_shape})
        output = ShExMap.generate_from(left_shex, right_shex, {target_iri => right_shape})
        expect(output).not_to be_nil
        expect(output).to have_same_statements_as(expected_graph)
      rescue ShEx::NotSatisfied => sns
        pp sns, sns.expression
        fail(sns)
      end
    end
  end

  Dir.open("testcases") do |tc_dir|
    tc_dir.each do |name|
      next if /^\./ =~ name
      FileTest.directory?("testcases/#{name}")
      it_should_behave_like "shex-map", name
    end
  end
end
