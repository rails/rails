# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  class Relation
    class WhereClause # :nodoc:
      delegate :any?, :empty?, to: :predicates

      def initialize(predicates)
        @predicates = predicates
      end

      def +(other)
        WhereClause.new(predicates + other.predicates)
      end

      def -(other)
        WhereClause.new(predicates - other.predicates)
      end

      def merge(other, rewhere = nil)
        predicates = if rewhere
          except_predicates(other.extract_attributes)
        else
          predicates_unreferenced_by(other)
        end

        WhereClause.new(predicates | other.predicates)
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
          left = left.ast
          left = left.expr if left.is_a?(Arel::Nodes::Grouping)

          right = right.ast
          right = right.expr if right.is_a?(Arel::Nodes::Grouping)

          or_clause = Arel::Nodes::Or.new(left, right)

          common.predicates << Arel::Nodes::Grouping.new(or_clause)
          common
        end
      end

      def to_h(table_name = nil)
        equalities(predicates).each_with_object({}) do |node, hash|
          next if table_name&.!= node.left.relation.name
          name = node.left.name.to_s
          value = extract_node_value(node.right)
          hash[name] = value
        end
      end

      def ast
        predicates = predicates_with_wrapped_sql_literals
        predicates.one? ? predicates.first : Arel::Nodes::And.new(predicates)
      end

      def ==(other)
        other.is_a?(WhereClause) &&
          predicates == other.predicates
      end

      def invert(as = :nand)
        if predicates.size == 1
          inverted_predicates = [ invert_predicate(predicates.first) ]
        elsif as == :nor
          inverted_predicates = predicates.map { |node| invert_predicate(node) }
        else
          inverted_predicates = [ Arel::Nodes::Not.new(ast) ]
        end

        WhereClause.new(inverted_predicates)
      end

      def self.empty
        @empty ||= new([]).tap(&:referenced_columns).freeze
      end

      def contradiction?
        predicates.any? do |x|
          case x
          when Arel::Nodes::In
            Array === x.right && x.right.empty?
          when Arel::Nodes::Equality
            x.right.respond_to?(:unboundable?) && x.right.unboundable?
          end
        end
      end

      def extract_attributes
        attrs = []
        predicates.each do |node|
          Arel.fetch_attribute(node) { |attr| attrs << attr } || begin
            attrs << node.left if node.equality? && node.left.is_a?(Arel::Predications)
          end
        end
        attrs
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
            if equality_node?(node)
              equalities << node
            elsif node.is_a?(Arel::Nodes::And)
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
          !node.is_a?(String) && node.equality?
        end

        def invert_predicate(node)
          case node
          when NilClass
            raise ArgumentError, "Invalid argument for .where.not(), got nil."
          when String
            Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(node))
          else
            node.invert
          end
        end

        def except_predicates(columns)
          attrs = columns.extract! { |node| node.is_a?(Arel::Attribute) }
          non_attrs = columns.extract! { |node| node.is_a?(Arel::Predications) }

          predicates.reject do |node|
            if !non_attrs.empty? && node.equality? && node.left.is_a?(Arel::Predications)
              non_attrs.include?(node.left)
            end || Arel.fetch_attribute(node) do |attr|
              attrs.include?(attr) || columns.include?(attr.name.to_s)
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
          when Arel::Nodes::BindParam, Arel::Nodes::Casted, Arel::Nodes::Quoted
            node.value_before_type_cast
          end
        end
    end
  end
end
