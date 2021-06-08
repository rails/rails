# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Polymorphic Association
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def klass
        type = owner[reflection.foreign_type]
        type.presence && owner.class.polymorphic_class_for(type)
      end

      def target_changed?
        super || owner.saved_change_to_attribute?(reflection.foreign_type)
      end

      private
        def replace_keys(record, force: false)
          super

          target_type = record ? record.class.polymorphic_name : nil

          if force || owner._read_attribute(reflection.foreign_type) != target_type
            owner[reflection.foreign_type] = target_type
          end
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
    end
  end
end
