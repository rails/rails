# frozen_string_literal: true

module ActiveRecord
  class Relation
    class WhereClause # :nodoc:
      delegate :any?, :empty?, to: :predicates

      def initialize(predicates)
        @predicates = predicates
      end

      def +(other)
        WhereClause.new(
          predicates + other.predicates,
        )
      end

      def -(other)
        WhereClause.new(
          predicates - other.predicates,
        )
      end

      def merge(other)
        WhereClause.new(
          predicates_unreferenced_by(other) + other.predicates,
        )
      end

      def except(*columns)
        WhereClause.new(except_predicates(columns))
      end

      def or(other)
        left = self - other
        common = self - left
        right = other - common

        if left.empty? || right.empty?
          common
        else
          or_clause = WhereClause.new(
            [left.ast.or(right.ast)],
          )
          common + or_clause
        end
      end

      def to_h(table_name = nil)
        equalities = equalities(predicates)
        if table_name
          equalities = equalities.select do |node|
            node.left.relation.name == table_name
          end
        end

        equalities.map { |node|
          name = node.left.name.to_s
          value = extract_node_value(node.right)
          [name, value]
        }.to_h
      end

      def ast
        Arel::Nodes::And.new(predicates_with_wrapped_sql_literals)
      end

      def ==(other)
        other.is_a?(WhereClause) &&
          predicates == other.predicates
      end

      def invert
        WhereClause.new(inverted_predicates)
      end

      def self.empty
        @empty ||= new([])
      end

      protected

        attr_reader :predicates

        def referenced_columns
          @referenced_columns ||= begin
            equality_nodes = predicates.select { |n| equality_node?(n) }
            Set.new(equality_nodes, &:left)
          end
        end

      private
        def equalities(predicates)
          equalities = []

          predicates.each do |node|
            case node
            when Arel::Nodes::Equality
              equalities << node
            when Arel::Nodes::And
              equalities.concat equalities(node.children)
            end
          end

          equalities
        end

        def predicates_unreferenced_by(other)
          predicates.reject do |n|
            equality_node?(n) && other.referenced_columns.include?(n.left)
          end
        end

        def equality_node?(node)
          node.respond_to?(:operator) && node.operator == :==
        end

        def inverted_predicates
          predicates.map { |node| invert_predicate(node) }
        end

        def invert_predicate(node)
          case node
          when NilClass
            raise ArgumentError, "Invalid argument for .where.not(), got nil."
          when Arel::Nodes::In
            Arel::Nodes::NotIn.new(node.left, node.right)
          when Arel::Nodes::Equality
            Arel::Nodes::NotEqual.new(node.left, node.right)
          when String
            Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(node))
          else
            Arel::Nodes::Not.new(node)
          end
        end

        def except_predicates(columns)
          predicates.reject do |node|
            case node
            when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
              subrelation = (node.left.kind_of?(Arel::Attributes::Attribute) ? node.left : node.right)
              columns.include?(subrelation.name.to_s)
            end
          end
        end

        def predicates_with_wrapped_sql_literals
          non_empty_predicates.map do |node|
            case node
            when Arel::Nodes::SqlLiteral, ::String
              wrap_sql_literal(node)
            else node
            end
          end
        end

        ARRAY_WITH_EMPTY_STRING = [""]
        def non_empty_predicates
          predicates - ARRAY_WITH_EMPTY_STRING
        end

        def wrap_sql_literal(node)
          if ::String === node
            node = Arel.sql(node)
          end
          Arel::Nodes::Grouping.new(node)
        end

        def extract_node_value(node)
          case node
          when Array
            node.map { |v| extract_node_value(v) }
          when Arel::Nodes::Casted, Arel::Nodes::Quoted
            node.val
          when Arel::Nodes::BindParam
            value = node.value
            if value.respond_to?(:value_before_type_cast)
              value.value_before_type_cast
            else
              value
            end
          end
        end
    end
  end
end
