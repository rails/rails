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

            join_scope = reflection.join_scope(table, foreign_table, foreign_klass)

            arel = join_scope.arel(alias_tracker.aliases)
            nodes = arel.constraints.first

            others, children = nodes.children.partition do |node|
              !fetch_arel_attribute(node) { |attr| attr.relation.name == table.name }
            end
            nodes = table.create_and(children)

            joins << table.create_join(table, table.create_on(nodes), join_type)

            unless others.empty?
              joins.concat arel.join_sources
              append_constraints(joins.last, others)
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

        private
          def fetch_arel_attribute(value)
            case value
            when Arel::Nodes::Between, Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual, Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual
              yield value.left.is_a?(Arel::Attributes::Attribute) ? value.left : value.right
            end
          end

          def append_constraints(join, constraints)
            if join.is_a?(Arel::Nodes::StringJoin)
              join_string = table.create_and(constraints.unshift(join.left))
              join.left = Arel.sql(base_klass.connection.visitor.compile(join_string))
            else
              join.right.expr.children.concat(constraints)
            end
          end
      end
    end
  end
end
