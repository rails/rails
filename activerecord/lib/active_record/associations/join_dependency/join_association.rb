# frozen_string_literal: true

require "active_record/associations/join_dependency/join_part"
require "active_support/core_ext/array/extract"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        attr_reader :reflection, :tables
        attr_accessor :table

        def initialize(reflection, children)
          super(reflection.klass, children)

          @reflection = reflection
        end

        def match?(other)
          return true if self == other
          super && reflection == other.reflection
        end

        def join_constraints(foreign_table, foreign_klass, join_type, alias_tracker)
          joins = []
          chain = []

          reflection_chain = reflection.chain
          reflection_chain.each_with_index do |reflection, index|
            table, terminated = yield reflection, reflection_chain[index..]
            @table ||= table

            if terminated
              foreign_table, foreign_klass = table, reflection.klass
              break
            end

            chain << [reflection, table]
          end

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse_each do |reflection, table|
            klass = reflection.klass

            scope = reflection.join_scope(table, foreign_table, foreign_klass)

            unless scope.references_values.empty?
              associations = scope.eager_load_values | scope.includes_values

              unless associations.empty?
                scope.joins! scope.construct_join_dependency(associations, Arel::Nodes::OuterJoin)
              end
            end

            arel = scope.arel(alias_tracker.aliases)

            if lateral_join?(scope, alias_tracker)
              # A plain join takes only the `ON` clause from the scope, which
              # cannot express a `LIMIT`/`OFFSET` per owner. Run the whole
              # scope once per row of the foreign table instead, correlated on
              # the join keys, so its `ORDER BY` and its own joins come along.
              joins << join_type.new(
                Arel::Nodes::TableAlias.new(Arel::Nodes::Lateral.new(arel.ast), table.name),
                Arel::Nodes::On.new(Arel::Nodes::True.new)
              )
            else
              nodes = arel.constraints.first

              if nodes.is_a?(Arel::Nodes::And)
                others = nodes.children.extract! do |node|
                  !Arel.fetch_attribute(node) { |attr| attr.relation.name == table.name }
                end
              end

              joins << join_type.new(table, Arel::Nodes::On.new(nodes))

              if others && !others.empty?
                joins.concat arel.join_sources
                append_constraints(joins.last, others)
              end
            end

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          joins
        end

        def readonly?
          return @readonly if defined?(@readonly)

          @readonly = reflection.scope && reflection.scope_for(base_klass.unscoped).readonly_value
        end

        def strict_loading?
          return @strict_loading if defined?(@strict_loading)

          @strict_loading = reflection.scope && reflection.scope_for(base_klass.unscoped).strict_loading_value
        end

        private
          # Without the option, or without `LATERAL` to apply them with, the
          # scope's `LIMIT`/`OFFSET` is dropped and every row comes back.
          def lateral_join?(scope, alias_tracker)
            ActiveRecord.respect_association_scope_limits &&
              (scope.limit_value || scope.offset_value) &&
              alias_tracker.supports_lateral_joins?
          end

          def append_constraints(join, constraints)
            if join.is_a?(Arel::Nodes::StringJoin)
              join_string = Arel::Nodes::And.new(constraints.unshift join.left)
              join.left = join_string
            else
              right = join.right
              right.expr = Arel::Nodes::And.new(constraints.unshift right.expr)
            end
          end
      end
    end
  end
end
