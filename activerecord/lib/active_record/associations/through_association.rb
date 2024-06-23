# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Through Association
    module ThroughAssociation # :nodoc:
      delegate :source_reflection, to: :reflection

      private
        def transaction(&block)
          through_reflection.klass.transaction(&block)
        end

        def through_reflection
          @through_reflection ||= begin
            refl = reflection.through_reflection

            while refl.through_reflection?
              refl = refl.through_reflection
            end

            refl
          end
        end

        def through_association
          @through_association ||= owner.association(through_reflection.name)
        end

        # We merge in these scopes for two reasons:
        #
        #   1. To get the default_scope conditions for any of the other reflections in the chain
        #   2. To get the type conditions for any STI models in the chain
        def target_scope
          scope = super
          reflection.chain.drop(1).each do |reflection|
            relation = reflection.klass.scope_for_association
            scope.merge!(
              relation.except(:select, :create_with, :includes, :preload, :eager_load, :joins, :left_outer_joins)
            )
          end
          scope
        end

        # Construct attributes for :through pointing to owner and associate. This is used by the
        # methods which create and delete records on the association.
        #
        # We only support indirectly modifying through associations which have a belongs_to source.
        # This is the "has_many :tags, through: :taggings" situation, where the join model
        # typically has a belongs_to on both side. In other words, associations which could also
        # be represented as has_and_belongs_to_many associations.
        #
        # We do not support creating/deleting records on the association where the source has
        # some other type, because this opens up a whole can of worms, and in basically any
        # situation it is more natural for the user to just create or modify their join records
        # directly as required.
        def construct_join_attributes(*records)
          ensure_mutable

          association_primary_key = source_reflection.association_primary_key(reflection.klass)

          if Array(association_primary_key) == reflection.klass.composite_query_constraints_list && !options[:source_type]
            join_attributes = { source_reflection.name => records }
          else
            assoc_pk_values = records.map { |record| record._read_attribute(association_primary_key) }
            join_attributes = { source_reflection.foreign_key => assoc_pk_values }
          end

          if options[:source_type]
            join_attributes[source_reflection.foreign_type] = [ options[:source_type] ]
          end

          if records.count == 1
            join_attributes.transform_values!(&:first)
          else
            join_attributes
          end
        end

        # Note: this does not capture all cases, for example it would be impractical
        # to try to properly support stale-checking for nested associations.
        def stale_state
          if through_reflection.belongs_to?
            Array(through_reflection.foreign_key).filter_map do |foreign_key_column|
              owner[foreign_key_column]
            end.presence
          end
        end

        def foreign_key_present?
          through_reflection.belongs_to? && Array(through_reflection.foreign_key).all? do |foreign_key_column|
            !owner[foreign_key_column].nil?
          end
        end

        def ensure_mutable
          unless source_reflection.belongs_to?
            if reflection.has_one?
              raise HasOneThroughCantAssociateThroughHasOneOrManyReflection.new(owner, reflection)
            else
              raise HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(owner, reflection)
            end
          end
        end

        def ensure_not_nested
          if reflection.nested?
            if reflection.has_one?
              raise HasOneThroughNestedAssociationsAreReadonly.new(owner, reflection)
            else
              raise HasManyThroughNestedAssociationsAreReadonly.new(owner, reflection)
            end
          end
        end

        def build_record(attributes)
          if source_reflection.collection?
            inverse = source_reflection.inverse_of
            target = through_association.target

            if inverse && target && !target.is_a?(Array)
              Array(target.id).zip(Array(inverse.foreign_key)).map do |primary_key_value, foreign_key_column|
                attributes[foreign_key_column] = primary_key_value
              end
            end
          end

          super
        end
    end
  end
end
