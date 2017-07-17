module ActiveRecord
  class Relation
    class WhereClause # :nodoc:
      attr_reader :binds

      delegate :any?, :empty?, to: :predicates

      def initialize(predicates, binds)
        @predicates = predicates
        @binds = binds
      end

      # Useful to instantiate after using the #predicates_with_binds
      # Recieves [[predicate1, [bind11, bind12...]], [predicate2, [bind21, bind22...]]...]
      def self.from_zipped(predicates_and_binds)
        predicates, binds = predicates_and_binds.transpose

        WhereClause.new(
            predicates || [],
            (binds || []).flatten(1)
        )
      end

      def +(other)
        WhereClause.new(
          predicates + other.predicates,
          binds + other.binds,
        )
      end

      # Intersection
      def &(other)
        # Doing a poor man's array intersection since the predicates / binds don't define #hash
        other_predicates_with_binds = other.predicates_with_binds
        common_predicates_and_binds = self.predicates_with_binds.select { |pb| other_predicates_with_binds.include?(pb) }

        WhereClause.from_zipped(common_predicates_and_binds)
      end

      # Union, avoids adding duplicates
      # I wonder if this should be the behavior of #+
      def |(other)
        self + (other - self)
      end

      # Difference
      def -(other)
        # Doing a poor man's array difference since the predicates / binds don't define #hash
        other_predicates_with_binds = other.predicates_with_binds
        new_predicates_and_binds = self.predicates_with_binds.select { |pb| other_predicates_with_binds.exclude?(pb) }

        WhereClause.from_zipped(new_predicates_and_binds)
      end

      def merge(other)
        WhereClause.new(
          predicates_unreferenced_by(other) + other.predicates,
          non_conflicting_binds(other) + other.binds,
        )
      end

      def except(*columns)
        WhereClause.from_zipped(predicates_with_binds_except(columns))
      end

      def or(other)
        common, left, right = partition_common_left_right(other)

        return common if left.empty? || right.empty?

        added_or_clause = WhereClause.new(
            [left.ast.or(right.ast)],
            left.binds + right.binds
        )

        # Using union to avoid adding a clause that is already there
        common | added_or_clause
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
          name = node.left.name.to_s
          [name, binds.fetch(name) {
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

      def partition_common_left_right(other)
        # The simpler but possibly less efficient way. Thoughts?
        # common = self & other
        # left = self - common
        # right = other - common
        # return common, left, right

        other_predicates_with_binds = other.predicates_with_binds
        common, left = self.predicates_with_binds.partition { |pb| other_predicates_with_binds.include?(pb) }
        right = other_predicates_with_binds.reject { |pb| common.include?(pb) }

        [ WhereClause.from_zipped(common),
          WhereClause.from_zipped(left),
          WhereClause.from_zipped(right)]
      end

      protected

        def predicates_with_bind_ranges
          bind_index = 0
          self.predicates.map do |node|
            case node
            when Arel::Nodes::Node
              binds_contains = node.grep(Arel::Nodes::BindParam).size
            else
              binds_contains = 0
            end

            bind_range = bind_index...(bind_index + binds_contains)
            bind_index += binds_contains

            [node, bind_range]
          end
        end

        def predicates_with_binds
          self.predicates_with_bind_ranges.map do |node, bind_range|
            [node, self.binds[bind_range]]
          end
        end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :predicates

        def referenced_columns
          @referenced_columns ||= begin
            equality_nodes = predicates.select { |n| equality_node?(n) }
            Set.new(equality_nodes, &:left)
          end
        end

      private

        def predicates_unreferenced_by(other)
          predicates.reject do |n|
            equality_node?(n) && other.referenced_columns.include?(n.left)
          end
        end

        def equality_node?(node)
          node.respond_to?(:operator) && node.operator == :==
        end

        def non_conflicting_binds(other)
          conflicts = referenced_columns & other.referenced_columns
          conflicts.map! { |node| node.name.to_s }
          binds.reject { |attr| conflicts.include?(attr.name) }
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

        def predicates_with_binds_except(columns)
          self.predicates_with_binds.reject do |predicate, binds|
            case predicate
            when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
              subrelation = (predicate.left.kind_of?(Arel::Attributes::Attribute) ? predicate.left : predicate.right)
              columns.include?(subrelation.name.to_s)
            end
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
    end
  end
end
