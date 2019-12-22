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

        def visit_Arel_Nodes_InnerJoin(o)
          visit_edge o, "left"
          visit_edge o, "right"
        end
        alias :visit_Arel_Nodes_FullOuterJoin  :visit_Arel_Nodes_InnerJoin
        alias :visit_Arel_Nodes_OuterJoin      :visit_Arel_Nodes_InnerJoin
        alias :visit_Arel_Nodes_RightOuterJoin :visit_Arel_Nodes_InnerJoin

        def visit_Arel_Nodes_DeleteStatement(o)
          visit_edge o, "relation"
          visit_edge o, "wheres"
        end

        def unary(o)
          visit_edge o, "expr"
        end
        alias :visit_Arel_Nodes_Group             :unary
        alias :visit_Arel_Nodes_Cube              :unary
        alias :visit_Arel_Nodes_RollUp            :unary
        alias :visit_Arel_Nodes_GroupingSet       :unary
        alias :visit_Arel_Nodes_GroupingElement   :unary
        alias :visit_Arel_Nodes_Grouping          :unary
        alias :visit_Arel_Nodes_Having            :unary
        alias :visit_Arel_Nodes_Limit             :unary
        alias :visit_Arel_Nodes_Not               :unary
        alias :visit_Arel_Nodes_Offset            :unary
        alias :visit_Arel_Nodes_On                :unary
        alias :visit_Arel_Nodes_UnqualifiedColumn :unary
        alias :visit_Arel_Nodes_OptimizerHints    :unary
        alias :visit_Arel_Nodes_Preceding         :unary
        alias :visit_Arel_Nodes_Following         :unary
        alias :visit_Arel_Nodes_Rows              :unary
        alias :visit_Arel_Nodes_Range             :unary

        def window(o)
          visit_edge o, "partitions"
          visit_edge o, "orders"
          visit_edge o, "framing"
        end
        alias :visit_Arel_Nodes_Window            :window

        def named_window(o)
          visit_edge o, "partitions"
          visit_edge o, "orders"
          visit_edge o, "framing"
          visit_edge o, "name"
        end
        alias :visit_Arel_Nodes_NamedWindow       :named_window

        def function(o)
          visit_edge o, "expressions"
          visit_edge o, "distinct"
          visit_edge o, "alias"
        end
        alias :visit_Arel_Nodes_Exists :function
        alias :visit_Arel_Nodes_Min    :function
        alias :visit_Arel_Nodes_Max    :function
        alias :visit_Arel_Nodes_Avg    :function
        alias :visit_Arel_Nodes_Sum    :function

        def extract(o)
          visit_edge o, "expressions"
          visit_edge o, "alias"
        end
        alias :visit_Arel_Nodes_Extract :extract

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
        end

        def visit_Arel_Nodes_SelectCore(o)
          visit_edge o, "source"
          visit_edge o, "projections"
          visit_edge o, "wheres"
          visit_edge o,  "windows"
        end

        def visit_Arel_Nodes_SelectStatement(o)
          visit_edge o, "cores"
          visit_edge o, "limit"
          visit_edge o, "orders"
          visit_edge o, "offset"
        end

        def visit_Arel_Nodes_UpdateStatement(o)
          visit_edge o, "relation"
          visit_edge o, "wheres"
          visit_edge o, "values"
        end

        def visit_Arel_Table(o)
          visit_edge o, "name"
        end

        def visit_Arel_Nodes_Casted(o)
          visit_edge o, "val"
          visit_edge o, "attribute"
        end

        def visit_Arel_Attribute(o)
          visit_edge o, "relation"
          visit_edge o, "name"
        end
        alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
        alias :visit_Arel_Attributes_String :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute

        def nary(o)
          o.children.each_with_index do |x, i|
            edge(i) { visit x }
          end
        end
        alias :visit_Arel_Nodes_And :nary

        def binary(o)
          visit_edge o, "left"
          visit_edge o, "right"
        end
        alias :visit_Arel_Nodes_As                 :binary
        alias :visit_Arel_Nodes_Assignment         :binary
        alias :visit_Arel_Nodes_Between            :binary
        alias :visit_Arel_Nodes_Concat             :binary
        alias :visit_Arel_Nodes_DoesNotMatch       :binary
        alias :visit_Arel_Nodes_Equality           :binary
        alias :visit_Arel_Nodes_GreaterThan        :binary
        alias :visit_Arel_Nodes_GreaterThanOrEqual :binary
        alias :visit_Arel_Nodes_In                 :binary
        alias :visit_Arel_Nodes_JoinSource         :binary
        alias :visit_Arel_Nodes_LessThan           :binary
        alias :visit_Arel_Nodes_LessThanOrEqual    :binary
        alias :visit_Arel_Nodes_IsNotDistinctFrom  :binary
        alias :visit_Arel_Nodes_IsDistinctFrom     :binary
        alias :visit_Arel_Nodes_Matches            :binary
        alias :visit_Arel_Nodes_NotEqual           :binary
        alias :visit_Arel_Nodes_NotIn              :binary
        alias :visit_Arel_Nodes_Or                 :binary
        alias :visit_Arel_Nodes_Over               :binary

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

        def visit_Arel_Nodes_BindParam(o); end

        def visit_Hash(o)
          o.each_with_index do |pair, i|
            edge("pair_#{i}")   { visit pair }
          end
        end

        def visit_Array(o)
          o.each_with_index do |x, i|
            edge(i) { visit x }
          end
        end
        alias :visit_Set :visit_Array

        def visit_Arel_Nodes_Comment(o)
          visit_edge(o, "values")
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
