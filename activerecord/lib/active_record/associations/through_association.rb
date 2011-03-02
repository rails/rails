require 'enumerator'

module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation #:nodoc:

      delegate :source_options, :through_options, :source_reflection, :through_reflection,
               :through_reflection_chain, :through_conditions, :to => :reflection

      protected

        def target_scope
          super.merge(through_reflection.klass.scoped)
        end

        def association_scope
          scope = super.joins(construct_joins)
          scope = scope.where(reflection_conditions(0))

          unless options[:include]
            scope = scope.includes(source_options[:include])
          end

          scope
        end

      private

        # This scope affects the creation of the associated records (not the join records). At the
        # moment we only support creating on a :through association when the source reflection is a
        # belongs_to. Thus it's not necessary to set a foreign key on the associated record(s), so
        # this scope has can legitimately be empty.
        def creation_attributes
          { }
        end

        # TODO: Needed?
        def aliased_through_table
          name = through_reflection.table_name

          reflection.table_name == name ?
            through_reflection.klass.arel_table.alias(name + "_join") :
            through_reflection.klass.arel_table
        end

        def construct_owner_conditions
          reflection = through_reflection_chain.last

          if reflection.macro == :has_and_belongs_to_many
            table = tables[reflection].first
          else
            table = Array.wrap(tables[reflection]).first
          end

          super(table, reflection)
        end

        def construct_joins
          joins, right_index = [], 1

          # Iterate over each pair in the through reflection chain, joining them together
          through_reflection_chain.each_cons(2) do |left, right|
            left_table, right_table = tables[left], tables[right]

            if left.source_reflection.nil?
              case left.macro
                when :belongs_to
                  joins << inner_join(
                    right_table,
                    left_table[left.association_primary_key],
                    right_table[left.foreign_key],
                    reflection_conditions(right_index)
                  )
                when :has_many, :has_one
                  joins << inner_join(
                    right_table,
                    left_table[left.foreign_key],
                    right_table[right.association_primary_key],
                    polymorphic_conditions(left, left),
                    reflection_conditions(right_index)
                  )
                when :has_and_belongs_to_many
                  joins << inner_join(
                    right_table,
                    left_table.first[left.foreign_key],
                    right_table[right.klass.primary_key],
                    reflection_conditions(right_index)
                  )
              end
            else
              case left.source_reflection.macro
                when :belongs_to
                  joins << inner_join(
                    right_table,
                    left_table[left.association_primary_key],
                    right_table[left.foreign_key],
                    source_type_conditions(left),
                    reflection_conditions(right_index)
                  )
                when :has_many, :has_one
                  if right.macro == :has_and_belongs_to_many
                    join_table, right_table = tables[right]
                  end

                  joins << inner_join(
                    right_table,
                    left_table[left.foreign_key],
                    right_table[left.source_reflection.active_record_primary_key],
                    polymorphic_conditions(left, left.source_reflection),
                    reflection_conditions(right_index)
                  )

                  if right.macro == :has_and_belongs_to_many
                    joins << inner_join(
                      join_table,
                      right_table[right.klass.primary_key],
                      join_table[right.association_foreign_key]
                    )
                  end
                when :has_and_belongs_to_many
                  join_table, left_table = tables[left]

                  joins << inner_join(
                    join_table,
                    left_table[left.klass.primary_key],
                    join_table[left.association_foreign_key]
                  )

                  joins << inner_join(
                    right_table,
                    join_table[left.foreign_key],
                    right_table[right.klass.primary_key],
                    reflection_conditions(right_index)
                  )
              end
            end

            right_index += 1
          end

          joins
        end

        # Construct attributes for :through pointing to owner and associate. This is used by the
        # methods which create and delete records on the association.
        #
        # We only support indirectly modifying through associations which has a belongs_to source.
        # This is the "has_many :tags, :through => :taggings" situation, where the join model
        # typically has a belongs_to on both side. In other words, associations which could also
        # be represented as has_and_belongs_to_many associations.
        #
        # We do not support creating/deleting records on the association where the source has
        # some other type, because this opens up a whole can of worms, and in basically any
        # situation it is more natural for the user to just create or modify their join records
        # directly as required.
        def construct_join_attributes(*records)
          if source_reflection.macro != :belongs_to
            raise HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(owner, reflection)
          end

          join_attributes = {
            source_reflection.foreign_key =>
              records.map { |record|
                record.send(source_reflection.association_primary_key)
              }
          }

          if options[:source_type]
            join_attributes[source_reflection.foreign_type] =
              records.map { |record| record.class.base_class.name }
          end

          if records.count == 1
            Hash[join_attributes.map { |k, v| [k, v.first] }]
          else
            join_attributes
          end
        end

        def alias_tracker
          @alias_tracker ||= AliasTracker.new
        end

        # TODO: It is decidedly icky to have an array for habtm entries, and no array for others
        def tables
          @tables ||= begin
            Hash[
              through_reflection_chain.map do |reflection|
                table = alias_tracker.aliased_table_for(
                  reflection.table_name,
                  table_alias_for(reflection, reflection != self.reflection)
                )

                if reflection.macro == :has_and_belongs_to_many ||
                     (reflection.source_reflection &&
                      reflection.source_reflection.macro == :has_and_belongs_to_many)

                  join_table = alias_tracker.aliased_table_for(
                    (reflection.source_reflection || reflection).options[:join_table],
                    table_alias_for(reflection, true)
                  )

                  [reflection, [join_table, table]]
                else
                  [reflection, table]
                end
              end
            ]
          end
        end

        def table_alias_for(reflection, join = false)
          name = alias_tracker.pluralize(reflection.name)
          name << "_#{self.reflection.name}"
          name << "_join" if join
          name
        end

        def inner_join(table, left_column, right_column, *conditions)
          conditions << left_column.eq(right_column)

          table.create_join(
            table,
            table.create_on(table.create_and(conditions.flatten.compact)))
        end

        def reflection_conditions(index)
          reflection = through_reflection_chain[index]
          conditions = through_conditions[index].dup

          # TODO: maybe this should go in Reflection#through_conditions directly?
          unless reflection.klass.descends_from_active_record?
            conditions << reflection.klass.send(:type_condition)
          end

          unless conditions.empty?
            conditions.map! do |condition|
              condition = reflection.klass.send(:sanitize_sql, interpolate(condition), reflection.table_name)
              condition = Arel.sql(condition) unless condition.is_a?(Arel::Node)
              condition
            end

            Arel::Nodes::And.new(conditions)
          end
        end

        def polymorphic_conditions(reflection, polymorphic_reflection)
          if polymorphic_reflection.options[:as]
            tables[reflection][polymorphic_reflection.type].
              eq(polymorphic_reflection.active_record.base_class.name)
          end
        end

        def source_type_conditions(reflection)
          if reflection.options[:source_type]
            tables[reflection.through_reflection][reflection.foreign_type].
              eq(reflection.options[:source_type])
          end
        end

        # TODO: Think about this in the context of nested associations
        def stale_state
          if through_reflection.macro == :belongs_to
            owner[through_reflection.foreign_key].to_s
          end
        end

        def foreign_key_present?
          through_reflection.macro == :belongs_to &&
          !owner[through_reflection.foreign_key].nil?
        end

        def ensure_not_nested
          if reflection.nested?
            raise HasManyThroughNestedAssociationsAreReadonly.new(owner, reflection)
          end
        end
    end
  end
end
