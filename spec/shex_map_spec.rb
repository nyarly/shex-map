#require 'spec_helper'
require 'shex-map'

describe ShExMap do
  let(:map_iri) { RDF::URI.new("http://shex.io/extensions/Map/") }

  let(:start_iri) { RDF::URI.new("http://example/foo") }

  let(:left_shape) { RDF::URI.new("http://a.example/S1") }

  let(:graph) do
    g = RDF::Graph.new
    g.insert(RDF::Statement.new(start_iri, RDF::URI.new("http://example/x"), "a"))
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

  describe ".execute" do
    specify do
      left_shex.execute(graph, {start_iri => left_shape}, map: {target: right_shex})
      output = left_shex.extensions[map_iri.to_s].output_graph
      expect(output).not_to be_nil
    end
  end

end
