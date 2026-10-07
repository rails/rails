# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Polymorphic Association
    class BelongsToPolymorphicAssociation < BelongsToAssociation # :nodoc:
      def klass
        type = owner.read_attribute(foreign_type)
        type.presence && owner.class.polymorphic_class_for(type)
      end

      def target_changed?
        super || owner.attribute_changed?(foreign_type)
      end

      def target_previously_changed?
        super || owner.attribute_previously_changed?(foreign_type)
      end

      def saved_change_to_target?
        super || owner.saved_change_to_attribute?(foreign_type)
      end

      private
        def replace_keys(record, force: false)
          super

          target_type = record ? record.class.polymorphic_name : nil

          if force || owner.read_attribute(foreign_type) != target_type
            owner.write_attribute(foreign_type, target_type)
          end
        end

        def inverse_reflection_for(record)
          reflection.polymorphic_inverse_of(record.class)
        end

        def raise_on_type_mismatch!(record)
          # A polymorphic association cannot have a type mismatch, by definition
        end

        def stale_state
          if foreign_key = super
            [foreign_key, owner.read_attribute(foreign_type)]
          end
        end
    end
  end
end
