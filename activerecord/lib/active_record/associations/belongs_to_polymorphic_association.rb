module ActiveRecord
  # = Active Record Belongs To Polymorphic Association
  module Associations
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def klass
        polymorphic_name(owner[reflection.foreign_type].presence)
      end

      private

        def replace_keys(record)
          super
          owner[reflection.foreign_type] = record.class.base_class.name
        end

        def remove_keys
          super
          owner[reflection.foreign_type] = nil
        end

        def different_target?(record)
          super || record.class != klass
        end

        def inverse_reflection_for(record)
          reflection.polymorphic_inverse_of(record.class)
        end

        def raise_on_type_mismatch!(record)
          # A polymorphic association cannot have a type mismatch, by definition
        end

        def stale_state
          foreign_key = super
          foreign_key && [foreign_key.to_s, owner[reflection.foreign_type].to_s]
        end

        def polymorphic_name(type)
          if type
            blk = ActiveRecord::Base.derive_class_name_for_association_reflection
            if blk
              type = reflection.instance_exec(type, &blk)
            end
            type.constantize
          end
        end

    end
  end
end
