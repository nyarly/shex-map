require 'shex-map'

RSpec::Matchers.define :have_same_statements_as do |expected|
  def as_triples(graph)
    RDF::Writer.for(:ntriples).buffer do |w|
      graph.each_statement do |s|
        w << s
      end
    end
  end

  match do |actual|
    actual_stmts = actual.statements.clone
    expected_stmts = expected.statements

    unless actual_stmts.length == expected_stmts.length
      return false
    end
    expected_stmts.each do |es|
      i = actual_stmts.index(es)
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
  let(:map_iri) { RDF::URI.new("http://shex.io/extensions/Map/") }

  let(:start_iri) { RDF::URI.new("http://example/foo") }
  let(:target_iri) { RDF::URI.new("http://example/bar") }

  let(:left_shape) { RDF::URI.new("http://a.example/S1") }
  let(:right_shape) { RDF::URI.new("http://b.example/S1") }

  let(:graph) do
    g = RDF::Graph.new
    g.insert(RDF::Statement.new(start_iri, RDF::URI.new("http://example/x"), "P"))
    g
  end

  let(:parse_options) do
    {
      validate: true,
      debug: true,
      progress: true,
      prefixes: {
        nil => RDF::URI.new("http://example/"),
        ex: RDF::URI.new("http://example/"),
        xsd: RDF::URI.new("http://www.w3.org/2001/XMLSchema#"),
        map: map_iri
      }
    }
  end


  let(:left_input) {
    %(<http://a.example/S1> {
      ex:x xsd:string %map: {ex:a%}
    })
  }
  let(:right_input) {
    %(<http://b.example/S1> {
      ex:z xsd:string %map: {ex:a%}
    })
  }

  let(:left_shex) { ShEx.parse(left_input, **parse_options) }
  let(:right_shex) { ShEx.parse(right_input, **parse_options) }

  def dump_graph(graph)
    puts (RDF::Writer.for(:ntriples).buffer do |w|
      graph.each_statement do |s|
        w << s
      end
    end)
  end

  describe ".execute" do
    specify do
      left_shex.execute(graph, {start_iri => left_shape})
      output = left_shex.extensions[map_iri.to_s].generate(right_shex, {target_iri => right_shape})
      puts "Input:"
      dump_graph(graph)
      puts "Output:"
      dump_graph(output)
      expect(output).not_to be_nil
      expected_graph = RDF::Graph.new
      expected_graph.insert(RDF::Statement.new(target_iri, RDF::URI.new("http://example/z"), "P"))
      expect(output).to have_same_statements_as(expected_graph)

    end
  end

end
