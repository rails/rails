# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Polymorphic Association
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def inversed_from(record)
        target_key  = record_target_key(record)
        target_type = record_target_type(record)
        if owner[reflection.foreign_key] != target_key || owner[reflection.foreign_type] != target_type
          replace_keys(record, target_key, target_type)
        end
        super
      end

      def klass
        type = owner[reflection.foreign_type]
        type.presence && owner.class.polymorphic_class_for(type)
      end

      def target_changed?
        super || owner.saved_change_to_attribute?(reflection.foreign_type)
      end

      private
        def replace(record)
          if record
            raise_on_type_mismatch!(record)
            set_inverse_instance(record)
            @updated = true
          end

          replace_keys(record_target_key(record), record_target_type(record))

          self.target = record
        end

        def replace_keys(target_key, target_type)
          super(target_key)
          owner[reflection.foreign_type] = target_type
        end

        def record_target_type(record)
          record ? record.class.polymorphic_name : nil
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
