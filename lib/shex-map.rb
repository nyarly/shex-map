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
        @segments = Hash.new do |h,op|
          h[op] = PathSegment.new(op)
        end

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
            v = Variable.new(code, path.clone.map{|op| segment_for(op)})
            variables[v.name] = v
          end
        end
        ops = oper.operands
        ops.each do |op|
          walk_op(op, path + [oper])
        end
      end

      def segment_for(op)
        @segments[op]
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
        @name ||= ShEx::Algebra::Operator.iri(@rawname.to_s, prefixes: @prefixes)
      end
    end

    class Variable
      attr :name, :path
      def initialize(code, path)
        @name = code.to_s
        @path = path
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

    class NodeGenerator
      def initialize(operator)
        @operator = operator
        @node = nil
        @count = 0
      end

      def next
        if @node.nil?
          @node = RDF::Node.new
        end

        if @count >= @operator.maximum
          @node = RDF::Node.new
        end

        @count+=1
        return @node
      end
    end

    class PathSegment
      def initialize(operator)
        @operator = operator
        @bnodes = Hash.new do |h,k|
          h[k] = NodeGenerator.new(operator)
        end
      end

      def add_edge(value, graph)
        bnode = @bnodes[graph].next
        if @operator.inverse?
          graph.insert(RDF::Statement.new(value, @operator.predicate, bnode))
        else
          graph.insert(RDF::Statement.new(bnode, @operator.predicate, value))
        end
        bnode
      end

      def bind(value, graph)
        return value unless @operator.is_a? ShEx::Algebra::TripleConstraint
        add_edge(value, graph)
      end
    end

    class RootSegment
      def initialize(iri)
        @root_iri = iri
      end

      def bind(value, graph)
        graph.each_statement do |stmt|
          if stmt.subject == value
            graph.delete(stmt)
            stmt.subject = @root_iri
            graph.insert(stmt)
          end
          if stmt.object == value
            graph.delete(stmt)
            stmt.object = @root_iri
            graph.insert(stmt)
          end
        end
      end
    end

    attr :bindings

    # Called to initialize module before evaluating shape
    def initialize(schema: nil, depth: 0, logger: nil, **options)
      @bindings = []
      @prefixes = Extension.stringify(schema.options[:prefixes])
      super
    end

    # Called on entry to containing Triple Expression
    def exit(code: nil, matched: [], unmatched: [], depth: 0, **options)
    end

    # Called after shape completes on success or failure
    def close(schema: nil, depth: 0, **options)
    end

    # Called on entry to containing Triple Expression
    def enter(code: nil, arcs_in: nil, arcs_out: nil, depth: 0, **options)
    end

    # Called once for each matched statement
    def visit(code: nil, matched: nil, depth: 0, **options)
      @bindings << Binding.new(@prefixes, code, matched.object)
      true
    end

    def generate(schema, map)
      g = Generator.new(schema, map)
      g.process(bindings)
    end
  end
end
