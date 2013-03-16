module Arel
  module Visitors
    class DepthFirst < Arel::Visitors::Visitor
      def initialize block = nil
        @block = block || Proc.new
      end

      private

      def visit o, a = nil
        super
        @block.call o
      end

      def unary o, a
        visit o.expr, a
      end
      alias :visit_Arel_Nodes_Group             :unary
      alias :visit_Arel_Nodes_Grouping          :unary
      alias :visit_Arel_Nodes_Having            :unary
      alias :visit_Arel_Nodes_Limit             :unary
      alias :visit_Arel_Nodes_Not               :unary
      alias :visit_Arel_Nodes_Offset            :unary
      alias :visit_Arel_Nodes_On                :unary
      alias :visit_Arel_Nodes_Ordering          :unary
      alias :visit_Arel_Nodes_Ascending         :unary
      alias :visit_Arel_Nodes_Descending        :unary
      alias :visit_Arel_Nodes_Top               :unary
      alias :visit_Arel_Nodes_UnqualifiedColumn :unary

      def function o, a
        visit o.expressions, a
        visit o.alias, a
        visit o.distinct, a
      end
      alias :visit_Arel_Nodes_Avg    :function
      alias :visit_Arel_Nodes_Exists :function
      alias :visit_Arel_Nodes_Max    :function
      alias :visit_Arel_Nodes_Min    :function
      alias :visit_Arel_Nodes_Sum    :function

      def visit_Arel_Nodes_NamedFunction o, a
        visit o.name, a
        visit o.expressions, a
        visit o.distinct, a
        visit o.alias, a
      end

      def visit_Arel_Nodes_Count o, a
        visit o.expressions, a
        visit o.alias, a
        visit o.distinct, a
      end

      def nary o, a
        o.children.each { |child| visit child, a }
      end
      alias :visit_Arel_Nodes_And :nary

      def binary o, a
        visit o.left, a
        visit o.right, a
      end
      alias :visit_Arel_Nodes_As                 :binary
      alias :visit_Arel_Nodes_Assignment         :binary
      alias :visit_Arel_Nodes_Between            :binary
      alias :visit_Arel_Nodes_DeleteStatement    :binary
      alias :visit_Arel_Nodes_DoesNotMatch       :binary
      alias :visit_Arel_Nodes_Equality           :binary
      alias :visit_Arel_Nodes_GreaterThan        :binary
      alias :visit_Arel_Nodes_GreaterThanOrEqual :binary
      alias :visit_Arel_Nodes_In                 :binary
      alias :visit_Arel_Nodes_InfixOperation     :binary
      alias :visit_Arel_Nodes_JoinSource         :binary
      alias :visit_Arel_Nodes_InnerJoin          :binary
      alias :visit_Arel_Nodes_LessThan           :binary
      alias :visit_Arel_Nodes_LessThanOrEqual    :binary
      alias :visit_Arel_Nodes_Matches            :binary
      alias :visit_Arel_Nodes_NotEqual           :binary
      alias :visit_Arel_Nodes_NotIn              :binary
      alias :visit_Arel_Nodes_Or                 :binary
      alias :visit_Arel_Nodes_OuterJoin          :binary
      alias :visit_Arel_Nodes_TableAlias         :binary
      alias :visit_Arel_Nodes_Values             :binary

      def visit_Arel_Nodes_StringJoin o, a
        visit o.left, a
      end

      def visit_Arel_Attribute o, a
        visit o.relation, a
        visit o.name, a
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attribute

      def visit_Arel_Table o, a
        visit o.name, a
      end

      def terminal o, a
      end
      alias :visit_ActiveSupport_Multibyte_Chars :terminal
      alias :visit_ActiveSupport_StringInquirer  :terminal
      alias :visit_Arel_Nodes_Lock               :terminal
      alias :visit_Arel_Nodes_Node               :terminal
      alias :visit_Arel_Nodes_SqlLiteral         :terminal
      alias :visit_Arel_Nodes_BindParam          :terminal
      alias :visit_Arel_Nodes_Window             :terminal
      alias :visit_Arel_SqlLiteral               :terminal
      alias :visit_BigDecimal                    :terminal
      alias :visit_Bignum                        :terminal
      alias :visit_Class                         :terminal
      alias :visit_Date                          :terminal
      alias :visit_DateTime                      :terminal
      alias :visit_FalseClass                    :terminal
      alias :visit_Fixnum                        :terminal
      alias :visit_Float                         :terminal
      alias :visit_NilClass                      :terminal
      alias :visit_String                        :terminal
      alias :visit_Symbol                        :terminal
      alias :visit_Time                          :terminal
      alias :visit_TrueClass                     :terminal

      def visit_Arel_Nodes_InsertStatement o, a
        visit o.relation, a
        visit o.columns, a
        visit o.values, a
      end

      def visit_Arel_Nodes_SelectCore o, a
        visit o.projections, a
        visit o.source, a
        visit o.wheres, a
        visit o.groups, a
        visit o.windows, a
        visit o.having, a
      end

      def visit_Arel_Nodes_SelectStatement o, a
        visit o.cores, a
        visit o.orders, a
        visit o.limit, a
        visit o.lock, a
        visit o.offset, a
      end

      def visit_Arel_Nodes_UpdateStatement o, a
        visit o.relation, a
        visit o.values, a
        visit o.wheres, a
        visit o.orders, a
        visit o.limit, a
      end

      def visit_Array o, a
        o.each { |i| visit i, a }
      end

      def visit_Hash o, a
        o.each { |k,v| visit(k, a); visit(v, a) }
      end
    end
  end
end
