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
        WhereClause.new(
          predicates_unreferenced_by(other) + other.predicates,
          non_conflicting_binds(other) + other.binds,
        )
      end

      def except(*columns)
        WhereClause.new(*except_predicates_and_binds(columns))
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

        def node_referenced_by_other?(node, other)
          equality_node?(node) && other.referenced_columns.include?(node.left)
        end

        def predicates_unreferenced_by(other)
          predicates.reject do |n|
            node_referenced_by_other?(n, other)
          end
        end

        def equality_node?(node)
          node.respond_to?(:operator) && node.operator == :==
        end

        def non_conflicting_binds(other)
          # Store all predicates that had bound params in the order of their traversal
          # to work with them based on index
          predicates_with_binds = []
          predicates.each do |predicate|
            if predicate.is_a?(Arel::Nodes::Node)
              predicate.right.each do |node|
                if node.is_a?(Arel::Nodes::BindParam)
                  predicates_with_binds << predicate
                end
              end
            end
          end

          # Reject the binds for Equality nodes if they have been
          # referenced in one of the Equality predicates of 'other'
          binds.reject.with_index do |_bind, idx|
            predicate = predicates_with_binds[idx]
            node_referenced_by_other?(predicate, other)
          end
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

        def except_predicates_and_binds(columns)
          except_binds = []
          binds_index = 0

          predicates = self.predicates.reject do |node|
            except = \
              case node
              when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
                binds_contains = node.grep(Arel::Nodes::BindParam).size
                subrelation = (node.left.kind_of?(Arel::Attributes::Attribute) ? node.left : node.right)
                columns.include?(subrelation.name.to_s)
              end

            if except && binds_contains > 0
              (binds_index...(binds_index + binds_contains)).each do |i|
                except_binds[i] = true
              end
            end

            binds_index += binds_contains if binds_contains

            except
          end

          binds = self.binds.reject.with_index do |_, i|
            except_binds[i]
          end

          [predicates, binds]
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
