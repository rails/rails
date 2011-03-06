require 'enumerator'

module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation #:nodoc:

      delegate :source_options, :through_options, :source_reflection, :through_reflection,
               :through_reflection_chain, :through_conditions, :to => :reflection

      protected

        # We merge in these scopes for two reasons:
        #
        #   1. To get the scope_for_create on through reflection when building associated objects
        #   2. To get the type conditions for any STI classes in the chain
        #
        # TODO: Don't actually do this. Getting the creation attributes for a non-nested through
        #       is a special case. The rest (STI conditions) should be handled by the reflection
        #       itself.
        def target_scope
          scope = super
          through_reflection_chain[1..-1].each do |reflection|
            scope = scope.merge(reflection.klass.scoped)
          end
          scope
        end

        def association_scope
          scope = join_to(super)
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
          super(tables.last, through_reflection_chain.last)
        end

        def join_to(scope)
          joins  = []
          tables = tables().dup # FIXME: Ugly

          foreign_reflection = through_reflection_chain.first
          foreign_table      = tables.shift

          through_reflection_chain[1..-1].each_with_index do |reflection, i|
            i += 1
            table = tables.shift

            if foreign_reflection.source_reflection.nil?
              case foreign_reflection.macro
                when :belongs_to
                  joins << inner_join(
                    table,
                    foreign_table[foreign_reflection.association_primary_key],
                    table[foreign_reflection.foreign_key],
                    reflection_conditions(i)
                  )
                when :has_many, :has_one
                  joins << inner_join(
                    table,
                    foreign_table[foreign_reflection.foreign_key],
                    table[reflection.association_primary_key],
                    reflection_conditions(i)
                  )
                when :has_and_belongs_to_many
                  join_table = foreign_table

                  joins << inner_join(
                    table,
                    join_table[foreign_reflection.foreign_key],
                    table[reflection.klass.primary_key],
                    reflection_conditions(i)
                  )
              end
            else
              case foreign_reflection.source_reflection.macro
                when :belongs_to
                  joins << inner_join(
                    table,
                    foreign_table[foreign_reflection.association_primary_key],
                    table[foreign_reflection.foreign_key],
                    reflection_conditions(i)
                  )
                when :has_many, :has_one
                  joins << inner_join(
                    table,
                    foreign_table[foreign_reflection.foreign_key],
                    table[foreign_reflection.source_reflection.active_record_primary_key],
                    reflection_conditions(i)
                  )

                  if reflection.macro == :has_and_belongs_to_many
                    join_table = tables.shift

                    joins << inner_join(
                      join_table,
                      table[reflection.klass.primary_key],
                      join_table[reflection.association_foreign_key]
                    )

                    # hack to make it become the foreign_table
                    table = join_table
                  end
                when :has_and_belongs_to_many
                  join_table, table = table, tables.shift

                  joins << inner_join(
                    join_table,
                    foreign_table[foreign_reflection.klass.primary_key],
                    join_table[foreign_reflection.association_foreign_key]
                  )

                  joins << inner_join(
                    table,
                    join_table[foreign_reflection.foreign_key],
                    table[reflection.klass.primary_key],
                    reflection_conditions(i)
                  )
              end
            end

            foreign_reflection = reflection
            foreign_table      = table
          end

          scope.joins(joins)
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

        def tables
          @tables ||= begin
            tables = []
            through_reflection_chain.each do |reflection|
              tables << alias_tracker.aliased_table_for(
                reflection.table_name,
                table_alias_for(reflection, reflection != self.reflection)
              )

              if reflection.macro == :has_and_belongs_to_many ||
                   (reflection.source_reflection &&
                    reflection.source_reflection.macro == :has_and_belongs_to_many)

                tables << alias_tracker.aliased_table_for(
                  (reflection.source_reflection || reflection).options[:join_table],
                  table_alias_for(reflection, true)
                )
              end
            end
            tables
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
          conditions = through_conditions[index]

          unless conditions.empty?
            Arel::Nodes::And.new(process_conditions(conditions, reflection))
          end
        end

        def process_conditions(conditions, reflection)
          conditions.map do |condition|
            condition = reflection.klass.send(:sanitize_sql, interpolate(condition), reflection.table_name)
            condition = Arel.sql(condition) unless condition.is_a?(Arel::Node)
            condition
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
