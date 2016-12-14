require "active_record/associations/join_dependency/join_part"

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

        def join_constraints(foreign_table, foreign_klass, node, join_type, tables, scope_chain, chain)
          joins         = []
          binds         = []
          tables        = tables.reverse

          scope_chain_index = 0
          scope_chain = scope_chain.reverse

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse_each do |reflection|
            table = tables.shift
            klass = reflection.klass

            join_keys   = reflection.join_keys(klass)
            key         = join_keys.key
            foreign_key = join_keys.foreign_key

            constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

            predicate_builder = PredicateBuilder.new(TableMetadata.new(klass, table))
            scope_chain_items = scope_chain[scope_chain_index].map do |item|
              if item.is_a?(Relation)
                item
              else
                ActiveRecord::Relation.create(klass, table, predicate_builder)
                  .instance_exec(node, &item)
              end
            end
            scope_chain_index += 1

            klass_scope =
              if klass.current_scope
                klass.current_scope.clone.tap { |scope|
                  scope.joins_values = []
                }
              else
                relation = ActiveRecord::Relation.create(
                  klass,
                  table,
                  predicate_builder,
                )
                klass.send(:build_default_scope, relation)
              end
            scope_chain_items.concat [klass_scope].compact

            rel = scope_chain_items.inject(scope_chain_items.shift) do |left, right|
              left.merge right
            end

            if rel && !rel.arel.constraints.empty?
              binds += rel.bound_attributes
              constraint = constraint.and rel.arel.constraints
            end

            if reflection.type
              value = foreign_klass.base_class.name
              column = klass.columns_hash[reflection.type.to_s]

              binds << Relation::QueryAttribute.new(column.name, value, klass.type_for_attribute(column.name))
              constraint = constraint.and klass.arel_attribute(reflection.type, table).eq(Arel::Nodes::BindParam.new)
            end

            joins << table.create_join(table, table.create_on(constraint), join_type)

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          JoinInformation.new joins, binds
        end

        #  Builds equality condition.
        #
        #  Example:
        #
        #  class Physician < ActiveRecord::Base
        #    has_many :appointments
        #  end
        #
        #  If I execute `Physician.joins(:appointments).to_a` then
        #    klass         # => Physician
        #    table         # => #<Arel::Table @name="appointments" ...>
        #    key           # =>  physician_id
        #    foreign_table # => #<Arel::Table @name="physicians" ...>
        #    foreign_key   # => id
        #
        def build_constraint(klass, table, key, foreign_table, foreign_key)
          constraint = table[key].eq(foreign_table[foreign_key])

          if klass.finder_needs_type_condition?
            constraint = table.create_and([
              constraint,
              klass.send(:type_condition, table)
            ])
          end

          constraint
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
