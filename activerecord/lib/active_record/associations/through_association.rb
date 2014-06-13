module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation #:nodoc:

      delegate :source_reflection, :through_reflection, :chain, :to => :reflection

      protected

        # We merge in these scopes for two reasons:
        #
        #   1. To get the default_scope conditions for any of the other reflections in the chain
        #   2. To get the type conditions for any STI models in the chain
        def target_scope
          scope = super
          chain.drop(1).each do |reflection|
            relation = reflection.klass.all
            relation.merge!(reflection.scope) if reflection.scope

            scope.merge!(
              relation.except(:select, :create_with, :includes, :preload, :joins, :eager_load)
            )
          end
          scope
        end

      private

        # Construct attributes for :through pointing to owner and associate. This is used by the
        # methods which create and delete records on the association.
        #
        # We only support indirectly modifying through associations which has a belongs_to source.
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

          if source_reflection.association_primary_key(reflection.klass) == reflection.klass.primary_key
            join_attributes = { source_reflection.name => records }
          else
            join_attributes = {
              source_reflection.foreign_key =>
                records.map { |record|
                  record.send(source_reflection.association_primary_key(reflection.klass))
                }
            }
          end

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

        # Note: this does not capture all cases, for example it would be crazy to try to
        # properly support stale-checking for nested associations.
        def stale_state
          if through_reflection.macro == :belongs_to
            owner[through_reflection.foreign_key] && owner[through_reflection.foreign_key].to_s
          end
        end

        def foreign_key_present?
          through_reflection.macro == :belongs_to &&
          !owner[through_reflection.foreign_key].nil?
        end

        def ensure_mutable
          if source_reflection.macro != :belongs_to
            raise HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(owner, reflection)
          end
        end

        def ensure_not_nested
          if reflection.nested?
            raise HasManyThroughNestedAssociationsAreReadonly.new(owner, reflection)
          end
        end
    end
  end
end
