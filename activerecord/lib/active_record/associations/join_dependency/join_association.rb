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
          where_conditions = []

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

            arel = scope.arel(aliases: alias_tracker.aliases)
            nodes = arel.constraints.first

            if nodes.is_a?(Arel::Nodes::And)
              others = nodes.children.extract! do |node|
                !Arel.fetch_attribute(node) { |attr| attr.relation.name == table.name }
              end
            end

            joins << join_type.new(table, Arel::Nodes::On.new(nodes))

            if others && !others.empty?
              joins.concat(arel.join_sources)
              where_conditions.concat(others)
            end

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          { joins:, where_conditions: }
        end

        def readonly?
          return @readonly if defined?(@readonly)

          @readonly = reflection.scope && reflection.scope_for(base_klass.unscoped).readonly_value
        end

        def strict_loading?
          return @strict_loading if defined?(@strict_loading)

          @strict_loading = reflection.scope && reflection.scope_for(base_klass.unscoped).strict_loading_value
        end
      end
    end
  end
end
