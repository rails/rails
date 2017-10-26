# frozen_string_literal: true

require "active_record/associations/join_dependency/join_part"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        # The reflection of the association represented
        attr_reader :reflection

        attr_accessor :tables

        def initialize(reflection, children, alias_tracker)
          super(reflection.klass, children)

          @alias_tracker = alias_tracker
          @reflection    = reflection
          @tables        = nil
        end

        def match?(other)
          return true if self == other
          super && reflection == other.reflection
        end

        def join_constraints(foreign_table, foreign_klass, join_type, tables, chain)
          joins         = []
          tables        = tables.reverse

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse_each do |reflection|
            table = tables.shift
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

        def table
          tables.first
        end

        protected
          attr_reader :alias_tracker
      end
    end
  end
end
