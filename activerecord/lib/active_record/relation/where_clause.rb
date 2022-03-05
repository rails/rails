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

      def |(other)
        WhereClause.new(predicates | other.predicates)
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

      def to_h(table_name = nil, equality_only: false)
        equalities(predicates, equality_only).each_with_object({}) do |node, hash|
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
      alias :eql? :==

      def hash
        [self.class, predicates].hash
      end

      def invert
        if predicates.any? { |pred| pred.nil? }
          raise ArgumentError, "Invalid argument for .where.not(), got nil."
        end

        attrs_need_null_preds = attributes_need_null_preds
        if predicates.size == 1
          # We can't treat a predicate as a special case of a group of predicates for
          # the unscope compatible reason. (e.g. unscope(where: :foo))
          predicate = predicates.first
          inverted_predicate = invert_predicate(predicate)

          if attrs_need_null_preds.present?
            attribute = attrs_need_null_preds.first
            is_null =
              Arel::Nodes::IsNotDistinctFrom.new(
                attribute, Arel::Nodes.build_quoted(nil, attribute))
            inverted_predicate =
              # we wrap it with a grouping to avoid conflict with others
              Arel::Nodes::Grouping.new(
                Arel::Nodes::Or.new(inverted_predicate, is_null))
          end

          inverted_predicates = [inverted_predicate]
        else
          is_not_null_predicates = attrs_need_null_preds.uniq.map do |attribute|
            Arel::Nodes::IsDistinctFrom.new(
              attribute, Arel::Nodes.build_quoted(nil, attribute))
          end

          predicate = ast
          predicate =
            predicate.is_a?(Arel::Nodes::And) ? predicate.children : [predicate]
          predicate = Arel::Nodes::And.new(predicate + is_not_null_predicates)
          inverted_predicates = [Arel::Nodes::Not.new(predicate)]
        end

        WhereClause.new(inverted_predicates)
      end

      def self.empty
        @empty ||= new([]).freeze
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
        each_attributes { |attr, _| attrs << attr }
        attrs
      end

      protected
        attr_reader :predicates

        def referenced_columns
          hash = {}
          each_attributes { |attr, node| hash[attr] = node }
          hash
        end

      private
        def attributes_need_null_preds
          attributes.filter_map do |attribute, node|
            case node
            when Arel::Nodes::Equality
              next false if node.right.nil?
            when Arel::Nodes::HomogeneousIn
              next false if node.type != :in
            else next false
            end

            nullable_attribute?(attribute) && attribute
          end
        end

        def nullable_attribute?(attribute)
          columns_hash = attribute&.relation&.klass&.columns_hash
          return nil unless columns_hash
          columns_hash[attribute.name]&.null
        end

        def attributes
          predicates.filter_map do |node|
            attr = extract_attribute(node) || begin
              node.left if equality_node?(node) && node.left.is_a?(Arel::Predications)
            end

            [attr, node] if attr
          end
        end

        def each_attributes
          attributes.each do |attr, node|
            yield attr, node
          end
        end

        def extract_attribute(node)
          attr_node = nil
          Arel.fetch_attribute(node) do |attr|
            return if attr_node&.!= attr # all attr nodes should be the same
            attr_node = attr
          end
          attr_node
        end

        def equalities(predicates, equality_only)
          equalities = []

          predicates.each do |node|
            if equality_only ? Arel::Nodes::Equality === node : equality_node?(node)
              equalities << node
            elsif node.is_a?(Arel::Nodes::And)
              equalities.concat equalities(node.children, equality_only)
            end
          end

          equalities
        end

        def predicates_unreferenced_by(other)
          referenced_columns = other.referenced_columns

          predicates.reject do |node|
            attr = extract_attribute(node) || begin
              node.left if equality_node?(node) && node.left.is_a?(Arel::Predications)
            end

            attr && referenced_columns[attr]
          end
        end

        def equality_node?(node)
          !node.is_a?(String) && node.equality?
        end

        def invert_predicate(node)
          case node
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
          if node.respond_to?(:value_before_type_cast)
            node.value_before_type_cast
          elsif Array === node
            node.map { |v| extract_node_value(v) }
          end
        end
    end
  end
end
