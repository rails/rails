# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class DepthFirst < Arel::Visitors::Visitor
      def initialize(block = nil)
        @block = block || Proc.new
        super()
      end

      private

        def visit(o, _ = nil)
          super
          @block.call o
        end

        def unary(o)
          visit o.expr
        end
        alias :visit_Arel_Nodes_Else              :unary
        alias :visit_Arel_Nodes_Group             :unary
        alias :visit_Arel_Nodes_Cube              :unary
        alias :visit_Arel_Nodes_RollUp            :unary
        alias :visit_Arel_Nodes_GroupingSet       :unary
        alias :visit_Arel_Nodes_GroupingElement   :unary
        alias :visit_Arel_Nodes_Grouping          :unary
        alias :visit_Arel_Nodes_Having            :unary
        alias :visit_Arel_Nodes_Lateral           :unary
        alias :visit_Arel_Nodes_Limit             :unary
        alias :visit_Arel_Nodes_Not               :unary
        alias :visit_Arel_Nodes_Offset            :unary
        alias :visit_Arel_Nodes_On                :unary
        alias :visit_Arel_Nodes_Ordering          :unary
        alias :visit_Arel_Nodes_Ascending         :unary
        alias :visit_Arel_Nodes_Descending        :unary
        alias :visit_Arel_Nodes_UnqualifiedColumn :unary
        alias :visit_Arel_Nodes_OptimizerHints    :unary
        alias :visit_Arel_Nodes_ValuesList        :unary

        def function(o)
          visit o.expressions
          visit o.alias
          visit o.distinct
        end
        alias :visit_Arel_Nodes_Avg    :function
        alias :visit_Arel_Nodes_Exists :function
        alias :visit_Arel_Nodes_Max    :function
        alias :visit_Arel_Nodes_Min    :function
        alias :visit_Arel_Nodes_Sum    :function

        def visit_Arel_Nodes_NamedFunction(o)
          visit o.name
          visit o.expressions
          visit o.distinct
          visit o.alias
        end

        def visit_Arel_Nodes_Count(o)
          visit o.expressions
          visit o.alias
          visit o.distinct
        end

        def visit_Arel_Nodes_Case(o)
          visit o.case
          visit o.conditions
          visit o.default
        end

        def nary(o)
          o.children.each { |child| visit child }
        end
        alias :visit_Arel_Nodes_And :nary

        def binary(o)
          visit o.left
          visit o.right
        end
        alias :visit_Arel_Nodes_As                 :binary
        alias :visit_Arel_Nodes_Assignment         :binary
        alias :visit_Arel_Nodes_Between            :binary
        alias :visit_Arel_Nodes_Concat             :binary
        alias :visit_Arel_Nodes_DeleteStatement    :binary
        alias :visit_Arel_Nodes_DoesNotMatch       :binary
        alias :visit_Arel_Nodes_Equality           :binary
        alias :visit_Arel_Nodes_FullOuterJoin      :binary
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
        alias :visit_Arel_Nodes_NotRegexp          :binary
        alias :visit_Arel_Nodes_IsNotDistinctFrom  :binary
        alias :visit_Arel_Nodes_IsDistinctFrom     :binary
        alias :visit_Arel_Nodes_Or                 :binary
        alias :visit_Arel_Nodes_OuterJoin          :binary
        alias :visit_Arel_Nodes_Regexp             :binary
        alias :visit_Arel_Nodes_RightOuterJoin     :binary
        alias :visit_Arel_Nodes_TableAlias         :binary
        alias :visit_Arel_Nodes_When               :binary

        def visit_Arel_Nodes_StringJoin(o)
          visit o.left
        end

        def visit_Arel_Attribute(o)
          visit o.relation
          visit o.name
        end
        alias :visit_Arel_Attributes_Integer :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Float :visit_Arel_Attribute
        alias :visit_Arel_Attributes_String :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Time :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Boolean :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Attribute :visit_Arel_Attribute
        alias :visit_Arel_Attributes_Decimal :visit_Arel_Attribute

        def visit_Arel_Table(o)
          visit o.name
        end

        def terminal(o)
        end
        alias :visit_ActiveSupport_Multibyte_Chars :terminal
        alias :visit_ActiveSupport_StringInquirer  :terminal
        alias :visit_Arel_Nodes_Lock               :terminal
        alias :visit_Arel_Nodes_Node               :terminal
        alias :visit_Arel_Nodes_SqlLiteral         :terminal
        alias :visit_Arel_Nodes_BindParam          :terminal
        alias :visit_Arel_Nodes_Window             :terminal
        alias :visit_Arel_Nodes_True               :terminal
        alias :visit_Arel_Nodes_False              :terminal
        alias :visit_BigDecimal                    :terminal
        alias :visit_Class                         :terminal
        alias :visit_Date                          :terminal
        alias :visit_DateTime                      :terminal
        alias :visit_FalseClass                    :terminal
        alias :visit_Float                         :terminal
        alias :visit_Integer                       :terminal
        alias :visit_NilClass                      :terminal
        alias :visit_String                        :terminal
        alias :visit_Symbol                        :terminal
        alias :visit_Time                          :terminal
        alias :visit_TrueClass                     :terminal

        def visit_Arel_Nodes_InsertStatement(o)
          visit o.relation
          visit o.columns
          visit o.values
        end

        def visit_Arel_Nodes_SelectCore(o)
          visit o.projections
          visit o.source
          visit o.wheres
          visit o.groups
          visit o.windows
          visit o.havings
        end

        def visit_Arel_Nodes_SelectStatement(o)
          visit o.cores
          visit o.orders
          visit o.limit
          visit o.lock
          visit o.offset
        end

        def visit_Arel_Nodes_UpdateStatement(o)
          visit o.relation
          visit o.values
          visit o.wheres
          visit o.orders
          visit o.limit
        end

        def visit_Arel_Nodes_Comment(o)
          visit o.values
        end

        def visit_Array(o)
          o.each { |i| visit i }
        end
        alias :visit_Set :visit_Array

        def visit_Hash(o)
          o.each { |k, v| visit(k); visit(v) }
        end

        DISPATCH = dispatch_cache

        def get_dispatch_cache
          DISPATCH
        end
    end
  end
end
