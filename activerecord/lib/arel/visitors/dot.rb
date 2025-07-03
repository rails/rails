# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class Dot < Arel::Visitors::Visitor
      class Node # :nodoc:
        attr_accessor :name, :id, :fields

        def initialize(name, id, fields = [])
          @name   = name
          @id     = id
          @fields = fields
        end
      end

      class Edge < Struct.new :name, :from, :to # :nodoc:
      end

      def initialize
        super()
        @nodes      = []
        @edges      = []
        @node_stack = []
        @edge_stack = []
        @seen       = {}
      end

      def accept(object, collector)
        visit object
        collector << to_dot
      end

      private
        def visit_Arel_Nodes_Function(o)
          visit_edge o, "expressions"
          visit_edge o, "distinct"
          visit_edge o, "alias"
        end

        def visit_Arel_Nodes_Unary(o)
          visit_edge o, "expr"
        end

        def visit_Arel_Nodes_Binary(o)
          visit_edge o, "left"
          visit_edge o, "right"
        end

        def visit_Arel_Nodes_UnaryOperation(o)
          visit_edge o, "operator"
          visit_edge o, "expr"
        end

        def visit_Arel_Nodes_InfixOperation(o)
          visit_edge o, "operator"
          visit_edge o, "left"
          visit_edge o, "right"
        end

        def visit__regexp(o)
          visit_edge o, "left"
          visit_edge o, "right"
          visit_edge o, "case_sensitive"
        end
        alias :visit_Arel_Nodes_Regexp :visit__regexp
        alias :visit_Arel_Nodes_NotRegexp :visit__regexp

        def visit_Arel_Nodes_Ordering(o)
          visit_edge o, "expr"
        end

        def visit_Arel_Nodes_TableAlias(o)
          visit_edge o, "name"
          visit_edge o, "relation"
        end

        def visit_Arel_Nodes_Count(o)
          visit_edge o, "expressions"
          visit_edge o, "distinct"
        end

        def visit_Arel_Nodes_ValuesList(o)
          visit_edge o, "rows"
        end

        def visit_Arel_Nodes_StringJoin(o)
          visit_edge o, "left"
        end

        def visit_Arel_Nodes_Window(o)
          visit_edge o, "partitions"
          visit_edge o, "orders"
          visit_edge o, "framing"
        end

        def visit_Arel_Nodes_NamedWindow(o)
          visit_edge o, "partitions"
          visit_edge o, "orders"
          visit_edge o, "framing"
          visit_edge o, "name"
        end

        def visit__no_edges(o)
          # intentionally left blank
        end
        alias :visit_Arel_Nodes_CurrentRow :visit__no_edges
        alias :visit_Arel_Nodes_Distinct :visit__no_edges

        def visit_Arel_Nodes_Extract(o)
          visit_edge o, "expressions"
          visit_edge o, "alias"
        end

        def visit_Arel_Nodes_NamedFunction(o)
          visit_edge o, "name"
          visit_edge o, "expressions"
          visit_edge o, "distinct"
          visit_edge o, "alias"
        end

        def visit_Arel_Nodes_InsertStatement(o)
          visit_edge o, "relation"
          visit_edge o, "columns"
          visit_edge o, "values"
          visit_edge o, "select"
        end

        def visit_Arel_Nodes_SelectCore(o)
          visit_edge o, "source"
          visit_edge o, "projections"
          visit_edge o, "wheres"
          visit_edge o, "windows"
          visit_edge o, "groups"
          visit_edge o, "comment"
          visit_edge o, "havings"
          visit_edge o, "set_quantifier"
          visit_edge o, "optimizer_hints"
        end

        def visit_Arel_Nodes_SelectStatement(o)
          visit_edge o, "cores"
          visit_edge o, "limit"
          visit_edge o, "orders"
          visit_edge o, "offset"
          visit_edge o, "lock"
          visit_edge o, "with"
        end

        def visit_Arel_Nodes_UpdateStatement(o)
          visit_edge o, "relation"
          visit_edge o, "wheres"
          visit_edge o, "values"
          visit_edge o, "orders"
          visit_edge o, "limit"
          visit_edge o, "offset"
          visit_edge o, "comment"
          visit_edge o, "key"
        end

        def visit_Arel_Nodes_DeleteStatement(o)
          visit_edge o, "relation"
          visit_edge o, "wheres"
          visit_edge o, "orders"
          visit_edge o, "limit"
          visit_edge o, "offset"
          visit_edge o, "comment"
          visit_edge o, "key"
        end

        def visit_Arel_Table(o)
          visit_edge o, "name"
        end

        def visit_Arel_Nodes_Casted(o)
          visit_edge o, "value"
          visit_edge o, "attribute"
        end

        def visit_Arel_Nodes_HomogeneousIn(o)
          visit_edge o, "values"
          visit_edge o, "type"
          visit_edge o, "attribute"
        end

        def visit_Arel_Attributes_Attribute(o)
          visit_edge o, "relation"
          visit_edge o, "name"
        end

        def visit__children(o)
          o.children.each_with_index do |child, i|
            edge(i) { visit child }
          end
        end
        alias :visit_Arel_Nodes_And :visit__children
        alias :visit_Arel_Nodes_Or :visit__children
        alias :visit_Arel_Nodes_With :visit__children

        def visit_String(o)
          @node_stack.last.fields << o
        end
        alias :visit_Time :visit_String
        alias :visit_Date :visit_String
        alias :visit_DateTime :visit_String
        alias :visit_NilClass :visit_String
        alias :visit_TrueClass :visit_String
        alias :visit_FalseClass :visit_String
        alias :visit_Integer :visit_String
        alias :visit_BigDecimal :visit_String
        alias :visit_Float :visit_String
        alias :visit_Symbol :visit_String
        alias :visit_Arel_Nodes_SqlLiteral :visit_String

        def visit_Arel_Nodes_BindParam(o)
          visit_edge(o, "value")
        end

        def visit_ActiveModel_Attribute(o)
          visit_edge(o, "value_before_type_cast")
        end

        def visit_Hash(o)
          o.each_with_index do |pair, i|
            edge("pair_#{i}") { visit pair }
          end
        end

        def visit_Array(o)
          o.each_with_index do |member, i|
            edge(i) { visit member }
          end
        end
        alias :visit_Set :visit_Array

        def visit_Arel_Nodes_Comment(o)
          visit_edge(o, "values")
        end

        def visit_Arel_Nodes_Case(o)
          visit_edge(o, "case")
          visit_edge(o, "conditions")
          visit_edge(o, "default")
        end

        def visit_edge(o, method)
          edge(method) { visit o.send(method) }
        end

        def visit(o)
          if node = @seen[o.object_id]
            @edge_stack.last.to = node
            return
          end

          node = Node.new(o.class.name, o.object_id)
          @seen[node.id] = node
          @nodes << node
          with_node node do
            super
          end
        end

        def edge(name)
          edge = Edge.new(name, @node_stack.last)
          @edge_stack.push edge
          @edges << edge
          yield
          @edge_stack.pop
        end

        def with_node(node)
          if edge = @edge_stack.last
            edge.to = node
          end

          @node_stack.push node
          yield
          @node_stack.pop
        end

        def quote(string)
          string.to_s.gsub('"', '\"')
        end

        def to_dot
          "digraph \"Arel\" {\nnode [width=0.375,height=0.25,shape=record];\n" +
            @nodes.map { |node|
              label = "<f0>#{node.name}"

              node.fields.each_with_index do |field, i|
                label += "|<f#{i + 1}>#{quote field}"
              end

              "#{node.id} [label=\"#{label}\"];"
            }.join("\n") + "\n" + @edges.map { |edge|
              "#{edge.from.id} -> #{edge.to.id} [label=\"#{edge.name}\"];"
            }.join("\n") + "\n}"
        end
    end
  end
end
