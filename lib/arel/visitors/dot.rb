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
      def visit_Arel_Nodes_Grouping o
        visit_edge o, "expr"
      end

      def visit_Arel_Nodes_Ordering o
        visit_edge o, "expr"
        visit_edge o, "direction"
      end

      def visit_Arel_Nodes_TableAlias o
        visit_edge o, "name"
        visit_edge o, "relation"
        visit_edge o, "columns"
      end

      def visit_Arel_Nodes_Sum o
        visit_edge o, "expressions"
        visit_edge o, "alias"
      end
      alias :visit_Arel_Nodes_Max :visit_Arel_Nodes_Sum
      alias :visit_Arel_Nodes_Avg :visit_Arel_Nodes_Sum

      def visit_Arel_Nodes_Count o
        visit_edge o, "expressions"
        visit_edge o, "distinct"
      end

      def visit_Arel_Nodes_On o
        visit_edge o, "expr"
      end

      def visit_Arel_Nodes_Values o
        visit_edge o, "expressions"
      end

      def visit_Arel_Nodes_StringJoin o
        visit_edge o, "left"
        visit_edge o, "right"
      end

      def visit_Arel_Nodes_InnerJoin o
        visit_edge o, "left"
        visit_edge o, "right"
        visit_edge o, "constraint"
      end
      alias :visit_Arel_Nodes_OuterJoin :visit_Arel_Nodes_InnerJoin

      def visit_Arel_Nodes_DeleteStatement o
        visit_edge o, "relation"
        visit_edge o, "wheres"
      end

      def visit_Arel_Nodes_UnqualifiedColumn o
        visit_edge o, "attribute"
      end

      def visit_Arel_Nodes_Offset o
        visit_edge o, "value"
      end

      def visit_Arel_Nodes_InsertStatement o
        visit_edge o, "relation"
        visit_edge o, "columns"
        visit_edge o, "values"
      end

      def visit_Arel_Nodes_SelectCore o
        visit_edge o, "froms"
        visit_edge o, "projections"
        visit_edge o, "wheres"
      end

      def visit_Arel_Nodes_SelectStatement o
        visit_edge o, "cores"
        visit_edge o, "limit"
        visit_edge o, "orders"
        visit_edge o, "offset"
      end

      def visit_Arel_Nodes_UpdateStatement o
        visit_edge o, "relation"
        visit_edge o, "wheres"
        visit_edge o, "values"
      end

      def visit_Arel_Table o
        visit_edge o, "name"
      end

      def visit_Arel_Attribute o
        visit_edge o, "relation"
        visit_edge o, "name"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute

      def visit_Arel_Nodes_Equality o
        visit_edge o, "left"
        visit_edge o, "right"
      end
      alias :visit_Arel_Nodes_And                :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_Or                 :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_NotEqual           :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_GreaterThan        :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_GreaterThanOrEqual :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_Assignment         :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_In                 :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_LessThan           :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_LessThanOrEqual    :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_Between            :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_NotIn              :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_DoesNotMatch       :visit_Arel_Nodes_Equality
      alias :visit_Arel_Nodes_Matches            :visit_Arel_Nodes_Equality

      def visit_String o
        @node_stack.last.fields << o
      end
      alias :visit_Time :visit_String
      alias :visit_Date :visit_String
      alias :visit_DateTime :visit_String
      alias :visit_NilClass :visit_String
      alias :visit_TrueClass :visit_String
      alias :visit_FalseClass :visit_String
      alias :visit_Arel_SqlLiteral :visit_String
      alias :visit_Fixnum :visit_String
      alias :visit_BigDecimal :visit_String
      alias :visit_Float :visit_String
      alias :visit_Symbol :visit_String
      alias :visit_Arel_Nodes_SqlLiteral :visit_String

      def visit_Hash o
        o.each_with_index do |pair, i|
          edge("pair_#{i}")   { visit pair }
        end
      end

      def visit_Array o
        o.each_with_index do |x,i|
          edge(i) { visit x }
        end
      end

      def visit_edge o, method
        edge(method) { visit o.send(method) }
      end

      def visit o
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
        "digraph \"ARel\" {\nnode [width=0.375,height=0.25,shape=record];\n" +
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
