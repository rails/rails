require 'active_record/associations/join_dependency/join_part'

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

            constraint = table[key].eq(foreign_table[foreign_key])

            #This has the constraints we need, but maybe an incorrect table alias
            starting_rel = klass.all

            #Create an empty rel with the correct alias
            predicate_builder = PredicateBuilder.new(TableMetadata.new(klass, table))
            rel = ActiveRecord::Relation.create(klass, table, predicate_builder)
            
            #merge the starting rel's constraints to the empty
            rel = rel.merge(starting_rel).unscope(:where).where(starting_rel.where_values_hash)

            scope_chain[scope_chain_index].each do |item|
              if item.is_a?(Relation)
                rel = rel.merge item
              else
                rel = rel.instance_exec(node, &item)
              end
            end
            scope_chain_index += 1

            if rel && !rel.arel.constraints.empty?
              binds += rel.bound_attributes
              constraint = constraint.and rel.arel.constraints
            end

            if reflection.type
              value = foreign_klass.base_class.name
              column = klass.columns_hash[reflection.type.to_s]

              substitute = klass.connection.substitute_at(column)
              binds << Relation::QueryAttribute.new(column.name, value, klass.type_for_attribute(column.name))
              constraint = constraint.and table[reflection.type].eq substitute
            end

            joins << table.create_join(table, table.create_on(constraint), join_type)

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
