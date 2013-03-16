module Arel
  module Visitors
    class Dot < Arel::Visitors::Visitor
      class Node # :nodoc:
        attr_accessor :name, :id, :fields

        def initialize name, id, fields = []
          @name   = name
          @id     = id
          @fields = fields
        end
      end

      class Edge < Struct.new :name, :from, :to # :nodoc:
      end

      def initialize
        @nodes      = []
        @edges      = []
        @node_stack = []
        @edge_stack = []
        @seen       = {}
      end

      def accept object
        super
        to_dot
      end

      private
      def visit_Arel_Nodes_Ordering o, a
        visit_edge o, a, "expr"
      end

      def visit_Arel_Nodes_TableAlias o, a
        visit_edge o, a, "name"
        visit_edge o, a, "relation"
      end

      def visit_Arel_Nodes_Count o, a
        visit_edge o, a, "expressions"
        visit_edge o, a, "distinct"
      end

      def visit_Arel_Nodes_Values o, a
        visit_edge o, a, "expressions"
      end

      def visit_Arel_Nodes_StringJoin o, a
        visit_edge o, a, "left"
      end

      def visit_Arel_Nodes_InnerJoin o, a
        visit_edge o, a, "left"
        visit_edge o, a, "right"
      end
      alias :visit_Arel_Nodes_OuterJoin :visit_Arel_Nodes_InnerJoin

      def visit_Arel_Nodes_DeleteStatement o, a
        visit_edge o, a, "relation"
        visit_edge o, a, "wheres"
      end

      def unary o, a
        visit_edge o, a, "expr"
      end
      alias :visit_Arel_Nodes_Group             :unary
      alias :visit_Arel_Nodes_Grouping          :unary
      alias :visit_Arel_Nodes_Having            :unary
      alias :visit_Arel_Nodes_Limit             :unary
      alias :visit_Arel_Nodes_Not               :unary
      alias :visit_Arel_Nodes_Offset            :unary
      alias :visit_Arel_Nodes_On                :unary
      alias :visit_Arel_Nodes_Top               :unary
      alias :visit_Arel_Nodes_UnqualifiedColumn :unary
      alias :visit_Arel_Nodes_Preceding         :unary
      alias :visit_Arel_Nodes_Following         :unary
      alias :visit_Arel_Nodes_Rows              :unary
      alias :visit_Arel_Nodes_Range             :unary

      def window o, a
        visit_edge o, a, "orders"
        visit_edge o, a, "framing"
      end
      alias :visit_Arel_Nodes_Window            :window

      def named_window o, a
        visit_edge o, a, "orders"
        visit_edge o, a, "framing"
        visit_edge o, a, "name"
      end
      alias :visit_Arel_Nodes_NamedWindow       :named_window

      def function o, a
        visit_edge o, a, "expressions"
        visit_edge o, a, "distinct"
        visit_edge o, a, "alias"
      end
      alias :visit_Arel_Nodes_Exists :function
      alias :visit_Arel_Nodes_Min    :function
      alias :visit_Arel_Nodes_Max    :function
      alias :visit_Arel_Nodes_Avg    :function
      alias :visit_Arel_Nodes_Sum    :function

      def extract o, a
        visit_edge o, a, "expressions"
        visit_edge o, a, "alias"
      end
      alias :visit_Arel_Nodes_Extract :extract

      def visit_Arel_Nodes_NamedFunction o, a
        visit_edge o, a, "name"
        visit_edge o, a, "expressions"
        visit_edge o, a, "distinct"
        visit_edge o, a, "alias"
      end

      def visit_Arel_Nodes_InsertStatement o, a
        visit_edge o, a, "relation"
        visit_edge o, a, "columns"
        visit_edge o, a, "values"
      end

      def visit_Arel_Nodes_SelectCore o, a
        visit_edge o, a, "source"
        visit_edge o, a, "projections"
        visit_edge o, a, "wheres"
        visit_edge o, a, "windows"
      end

      def visit_Arel_Nodes_SelectStatement o, a
        visit_edge o, a, "cores"
        visit_edge o, a, "limit"
        visit_edge o, a, "orders"
        visit_edge o, a, "offset"
      end

      def visit_Arel_Nodes_UpdateStatement o, a
        visit_edge o, a, "relation"
        visit_edge o, a, "wheres"
        visit_edge o, a, "values"
      end

      def visit_Arel_Table o, a
        visit_edge o, a, "name"
      end

      def visit_Arel_Attribute o, a
        visit_edge o, a, "relation"
        visit_edge o, a, "name"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute

      def nary o, a
        o.children.each_with_index do |x,i|
          edge(i) { visit x, a }
        end
      end
      alias :visit_Arel_Nodes_And :nary

      def binary o, a
        visit_edge o, a, "left"
        visit_edge o, a, "right"
      end
      alias :visit_Arel_Nodes_As                 :binary
      alias :visit_Arel_Nodes_Assignment         :binary
      alias :visit_Arel_Nodes_Between            :binary
      alias :visit_Arel_Nodes_DoesNotMatch       :binary
      alias :visit_Arel_Nodes_Equality           :binary
      alias :visit_Arel_Nodes_GreaterThan        :binary
      alias :visit_Arel_Nodes_GreaterThanOrEqual :binary
      alias :visit_Arel_Nodes_In                 :binary
      alias :visit_Arel_Nodes_JoinSource         :binary
      alias :visit_Arel_Nodes_LessThan           :binary
      alias :visit_Arel_Nodes_LessThanOrEqual    :binary
      alias :visit_Arel_Nodes_Matches            :binary
      alias :visit_Arel_Nodes_NotEqual           :binary
      alias :visit_Arel_Nodes_NotIn              :binary
      alias :visit_Arel_Nodes_Or                 :binary
      alias :visit_Arel_Nodes_Over               :binary

      def visit_String o, a
        @node_stack.last.fields << o
      end
      alias :visit_Time :visit_String
      alias :visit_Date :visit_String
      alias :visit_DateTime :visit_String
      alias :visit_NilClass :visit_String
      alias :visit_TrueClass :visit_String
      alias :visit_FalseClass :visit_String
      alias :visit_Arel_SqlLiteral :visit_String
      alias :visit_Arel_Nodes_BindParam :visit_String
      alias :visit_Fixnum :visit_String
      alias :visit_BigDecimal :visit_String
      alias :visit_Float :visit_String
      alias :visit_Symbol :visit_String
      alias :visit_Arel_Nodes_SqlLiteral :visit_String

      def visit_Hash o, a
        o.each_with_index do |pair, i|
          edge("pair_#{i}")   { visit pair, a }
        end
      end

      def visit_Array o, a
        o.each_with_index do |x,i|
          edge(i) { visit x, a }
        end
      end

      def visit_edge o, a, method
        edge(method) { visit o.send(method), a }
      end

      def visit o, a = nil
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

      def edge name
        edge = Edge.new(name, @node_stack.last)
        @edge_stack.push edge
        @edges << edge
        yield
        @edge_stack.pop
      end

      def with_node node
        if edge = @edge_stack.last
          edge.to = node
        end

        @node_stack.push node
        yield
        @node_stack.pop
      end

      def quote string
        string.to_s.gsub('"', '\"')
      end

      def to_dot
        "digraph \"Arel\" {\nnode [width=0.375,height=0.25,shape=record];\n" +
          @nodes.map { |node|
            label = "<f0>#{node.name}"

            node.fields.each_with_index do |field, i|
              label << "|<f#{i + 1}>#{quote field}"
            end

            "#{node.id} [label=\"#{label}\"];"
          }.join("\n") + "\n" + @edges.map { |edge|
            "#{edge.from.id} -> #{edge.to.id} [label=\"#{edge.name}\"];"
          }.join("\n") + "\n}"
      end
    end
  end
end
