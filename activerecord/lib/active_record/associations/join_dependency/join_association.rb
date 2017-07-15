require_relative "join_part"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        # The reflection of the association represented
        attr_reader :reflection

        attr_accessor :tables

        def initialize(reflection, children)
          super(reflection.klass, children)

          @reflection      = reflection
          @tables          = nil
        end

        def match?(other)
          return true if self == other
          super && reflection == other.reflection
        end

        JoinInformation = Struct.new :joins, :binds

        def join_constraints(foreign_table, foreign_klass, join_type, tables, chain)
          joins         = []
          binds         = []
          tables        = tables.reverse

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse_each do |reflection|
            table = tables.shift
            klass = reflection.klass

            constraint = reflection.build_join_constraint(table, foreign_table)

            joins << table.create_join(table, table.create_on(constraint), join_type)

            join_scope = reflection.join_scope(table, foreign_klass)

            if join_scope.arel.constraints.any?
              binds.concat join_scope.bound_attributes
              joins.concat join_scope.arel.join_sources
              right = joins.last.right
              right.expr = right.expr.and(join_scope.arel.constraints)
            end

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          JoinInformation.new joins, binds
        end

        def table
          tables.first
        end

        def aliased_table_name
          table.table_alias || table.name
        end
      end
    end
  end
end
