module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation #:nodoc:

      delegate :source_options, :through_options, :source_reflection, :through_reflection, :to => :reflection

      protected

        def target_scope
          super.merge(through_reflection.klass.scoped)
        end

        def association_scope
          scope = super.joins(construct_joins)
          scope = add_conditions(scope)
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

        def aliased_through_table
          name = through_reflection.table_name

          reflection.table_name == name ?
            through_reflection.klass.arel_table.alias(name + "_join") :
            through_reflection.klass.arel_table
        end

        def construct_owner_conditions
          super(aliased_through_table, through_reflection)
        end

        def construct_joins
          right = aliased_through_table
          left  = reflection.klass.arel_table

          conditions = []

          if source_reflection.macro == :belongs_to
            reflection_primary_key = source_reflection.association_primary_key
            source_primary_key     = source_reflection.foreign_key

            if options[:source_type]
              column = source_reflection.foreign_type
              conditions <<
                right[column].eq(options[:source_type])
            end
          else
            reflection_primary_key = source_reflection.foreign_key
            source_primary_key     = source_reflection.active_record_primary_key

            if source_options[:as]
              column = "#{source_options[:as]}_type"
              conditions <<
                left[column].eq(through_reflection.klass.name)
            end
          end

          conditions <<
            left[reflection_primary_key].eq(right[source_primary_key])

          right.create_join(
            right,
            right.create_on(right.create_and(conditions)))
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

        # The reason that we are operating directly on the scope here (rather than passing
        # back some arel conditions to be added to the scope) is because scope.where([x, y])
        # has a different meaning to scope.where(x).where(y) - the first version might
        # perform some substitution if x is a string.
        def add_conditions(scope)
          unless through_reflection.klass.descends_from_active_record?
            scope = scope.where(through_reflection.klass.send(:type_condition))
          end

          scope = scope.where(interpolate(source_options[:conditions]))
          scope.where(through_conditions)
        end

        # If there is a hash of conditions then we make sure the keys are scoped to the
        # through table name if left ambiguous.
        def through_conditions
          conditions = interpolate(through_options[:conditions])

          if conditions.is_a?(Hash)
            Hash[conditions.map { |key, value|
              unless value.is_a?(Hash) || key.to_s.include?('.')
                key = aliased_through_table.name + '.' + key.to_s
              end

              [key, value]
            }]
          else
            conditions
          end
        end

        def stale_state
          if through_reflection.macro == :belongs_to
            owner[through_reflection.foreign_key].to_s
          end
        end

        def foreign_key_present?
          through_reflection.macro == :belongs_to &&
          !owner[through_reflection.foreign_key].nil?
        end
    end
  end
end
