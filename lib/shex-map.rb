require 'shex'
require 'shex/extensions/extension'

require 'pp'

module ShExMap
  class Extension < ShEx::Extension("http://shex.io/extensions/Map/")
    # Called to initialize module before evaluating shape
    def initialize(schema: nil, depth: 0, logger: nil, **options)
      pp(:INIT, s: schema, d: depth)
      p options.keys
      pp options
      super
    end

    # Called on entry to containing Triple Expression
    def exit(code: nil, matched: [], unmatched: [], depth: 0, **options)
      p(:EXIT, c: code, m: matched, u: unmatched, d: depth)
      p options.keys
      p options
    end

    # Called after shape completes on success or failure
    def close(schema: nil, depth: 0, **options)
      p(:CLOSE, s: schema, d: depth)
      p options.keys
      p options
    end

    # Called on entry to containing Triple Expression
    def enter(code: nil, arcs_in: nil, arcs_out: nil, depth: 0, **options)
      p(:ENTER, c: code, in: arcs_in, out: arcs_out, d: depth, o: options)
    end

    # Called once for each matched statement
    def visit(code: nil, matched: nil, depth: 0, **options)
      p(:VISIT, c: code, m: matched, d: depth, o: options)
      p options.keys
      p options
      true
    end

    def output_graph
      g = RDF::Graph.new
      g.insert(RDF::Statement.new(RDF::URI.new("http://example/a"), RDF::URI.new("http://example/x"), "a"))
      g
    end
  end
end
