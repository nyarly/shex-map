require 'shex'
require 'shex/extensions/extension'

require 'pp'

module ShExMap
  EXTENSION_URL ="http://shex.io/extensions/Map/"
  def self.generate_from(left, right, map)
    left.extensions[EXTENSION_URL].generate(right, map)
  end

  class Extension < ShEx::Extension(EXTENSION_URL)
    def self.stringify(hash)
      string_prefixes = {}
      hash.each_pair do |k,v|
        if k.is_a? Symbol
          string_prefixes[k.to_s] = v
        end
      end
      string_prefixes.merge(hash)
    end

    class Generator
      attr :variables

      def initialize(schema, map, **options)
        @target_iri = map.values.first
        @output_root = map.keys.first
        @target = schema.find(@target_iri)
        @target_options = schema.options

        @variables = {}

        walk_op(@target, [])

        @target_options[:prefixes] = Extension.stringify(@target_options[:prefixes])

        expanded = {}
        @variables.each do |k,v|
          expanded[ @target.iri(k, @target_options) ] = v
        end
        @variables = expanded
        @variables.each_value do |var|
          var.root_at(@output_root)
        end
      end

      def walk_op(oper, path)
        return unless oper.respond_to? :operands
        if ShEx::Algebra::SemAct === oper
          ext, code = *oper.operands
          if ext == Extension.name
            v = Variable.new(code, path.clone)
            variables[v.name] = v
          end
        end
        ops = oper.operands
        ops.each do |op|
          walk_op(op, path + [oper])
        end
      end

      def process(bindings)
        g = RDF::Graph.new
        bindings.each do |b|
          v = @variables.fetch(b.name)
          v.bind(b,g)
        end
        g
      end
    end

    class Binding
      attr :prefixes, :rawname, :statement, :value

      def initialize(prefixes, name, value)
        @prefixes, @rawname, @value = prefixes, name, value
      end

      def name
        pp @prefixes
        @name ||= ShEx::Algebra::Operator.iri(@rawname.to_s, prefixes: @prefixes)
      end
    end

    class Variable
      attr :name, :path
      def initialize(code, path)
        @name = code.to_s
        @path = path.map{|op| PathSegment.new(op)}
      end

      def bind(binding, graph)
        value = binding.value
        @path.reverse.each do |segment|
          value = segment.bind(value, graph)
        end
      end

      def root_at(iri)
        @path[0] = RootSegment.new(iri)
      end
    end

    class PathSegment
      def initialize(operator)
        @operator = operator
      end

      def bind(value, graph)
        return value unless @operator.is_a? ShEx::Algebra::TripleConstraint
        bnode = RDF::Node.new
        graph.insert(RDF::Statement.new(bnode, @operator.predicate, value))
        bnode
      end
    end

    class RootSegment
      def initialize(iri)
        @root_iri = iri
      end

      def bind(value, graph)
        graph.each_statement do |stmt|
          pp stmt, value
          if stmt.subject == value
            pp @root_iri
            graph.delete(stmt)
            stmt.subject = @root_iri
            graph.insert(stmt)
            pp stmt
          end
        end
      end
    end

    attr :bindings

    # Called to initialize module before evaluating shape
    def initialize(schema: nil, depth: 0, logger: nil, **options)
      @bindings = []
      @prefixes = Extension.stringify(schema.options[:prefixes])
      p options
      super
    end

    # Called on entry to containing Triple Expression
    def exit(code: nil, matched: [], unmatched: [], depth: 0, **options)
      p(:EXIT, c: code, m: matched, u: unmatched, d: depth)
    end

    # Called after shape completes on success or failure
    def close(schema: nil, depth: 0, **options)
      p(:CLOSE, s: schema, d: depth)
    end

    # Called on entry to containing Triple Expression
    def enter(code: nil, arcs_in: nil, arcs_out: nil, depth: 0, **options)
      p(:ENTER, c: code, in: arcs_in, out: arcs_out, d: depth, o: options)
    end

    # Called once for each matched statement
    def visit(code: nil, matched: nil, depth: 0, **options)
      p(:VISIT, c: code, m: matched, d: depth, o: options)
      @bindings << Binding.new(@prefixes, code, matched.object)
      true
    end

    def generate(schema, map)
      g = Generator.new(schema, map)
      g.process(bindings)
    end
  end
end
