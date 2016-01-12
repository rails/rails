module ActiveRecord
  class Relation
    class WhereClause # :nodoc:
      attr_reader :binds

      delegate :any?, :empty?, to: :predicates

      def initialize(predicates, binds)
        @predicates = predicates
        @binds = binds
      end

      def +(other)
        WhereClause.new(
          predicates + other.predicates,
          binds + other.binds,
        )
      end

      def merge(other)
        conflict_indices = indices_of_predicates_referenced_by(other).to_set
        WhereClause.new(
          non_conflicting(predicates, conflict_indices) + other.predicates,
          non_conflicting(binds, conflict_indices) + other.binds,
        )
      end

      def except(*columns)
        WhereClause.new(
          predicates_except(columns),
          binds_except(columns),
        )
      end

      def or(other)
        if empty?
          self
        elsif other.empty?
          other
        else
          WhereClause.new(
            [ast.or(other.ast)],
            binds + other.binds
          )
        end
      end

      def to_h(table_name = nil)
        equalities = predicates.grep(Arel::Nodes::Equality)
        if table_name
          equalities = equalities.select do |node|
            node.left.relation.name == table_name
          end
        end

        binds = self.binds.map { |attr| [attr.name, attr.value] }.to_h

        equalities.map { |node|
          name = node.left.name
          [name, binds.fetch(name.to_s) {
            case node.right
            when Array then node.right.map(&:val)
            when Arel::Nodes::Casted, Arel::Nodes::Quoted
              node.right.val
            end
          }]
        }.to_h
      end

      def ast
        Arel::Nodes::And.new(predicates_with_wrapped_sql_literals)
      end

      def ==(other)
        other.is_a?(WhereClause) &&
          predicates == other.predicates &&
          binds == other.binds
      end

      def invert
        WhereClause.new(inverted_predicates, binds)
      end

      def self.empty
        @empty ||= new([], [])
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

      def indices_of_predicates_referenced_by(other)
        predicates.each_with_index.select do |(n, _)|
          equality_node?(n) && other.referenced_columns.include?(n.left)
        end.map(&:last)
      end

      def non_conflicting(values, conflict_indices)
        values.reject.with_index { |_, i| conflict_indices.include?(i) }
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
          raise ArgumentError, 'Invalid argument for .where.not(), got nil.'
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

      def predicates_except(columns)
        predicates.reject do |node|
          case node
          when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
            subrelation = (node.left.kind_of?(Arel::Attributes::Attribute) ? node.left : node.right)
            columns.include?(subrelation.name.to_s)
          end
        end
      end

      def binds_except(columns)
        binds.reject do |attr|
          columns.include?(attr.name)
        end
      end

      def predicates_with_wrapped_sql_literals
        non_empty_predicates.map do |node|
          if Arel::Nodes::Equality === node
            node
          else
            wrap_sql_literal(node)
          end
        end
      end

      def non_empty_predicates
        predicates - ['']
      end

      def wrap_sql_literal(node)
        if ::String === node
          node = Arel.sql(node)
        end
        Arel::Nodes::Grouping.new(node)
      end
    end
  end
end
