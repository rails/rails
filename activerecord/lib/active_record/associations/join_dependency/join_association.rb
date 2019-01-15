# frozen_string_literal: true

require "active_record/associations/join_dependency/join_part"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        attr_reader :reflection, :tables
        attr_accessor :table

        def initialize(reflection, children)
          super(reflection.klass, children)

          @reflection = reflection
          @tables     = nil
        end

        def match?(other)
          return true if self == other
          super && reflection == other.reflection
        end

        def join_constraints(foreign_table, foreign_klass, join_type, alias_tracker)
          joins = []

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          reflection.chain.reverse_each.with_index(1) do |reflection, i|
            table = tables[-i]
            klass = reflection.klass

            constraint = reflection.build_join_constraint(table, foreign_table)

            joins << table.create_join(table, table.create_on(constraint), join_type)

            join_scope = reflection.join_scope(table, foreign_klass)
            arel = join_scope.arel(alias_tracker.aliases)

            if arel.constraints.any?
              joins.concat arel.join_sources
              right = joins.last.right
              right.expr = right.expr.and(arel.constraints)
            end

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          joins
        end

        def tables=(tables)
          @tables = tables
          @table  = tables.first
        end

        def readonly?
          return @readonly if defined?(@readonly)

          @readonly = reflection.scope && reflection.scope_for(base_klass.unscoped).readonly_value
        end
      end
    end
  end
end
