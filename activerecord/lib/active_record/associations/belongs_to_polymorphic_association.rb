# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module Associations
    # Active Record Belongs To Polymorphic Association
    # ================================================
    class BelongsToPolymorphicAssociation < BelongsToAssociation # :nodoc:
      def klass
        type = owner._read_attr(foreign_type)
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
        def inverse_reflection_for(record)
          reflection.polymorphic_inverse_of(record.class)
        end

        def raise_on_type_mismatch!(record)
          # A polymorphic association cannot have a type mismatch, by definition
        end

        def stale_state
          if foreign_key = super
            [foreign_key, owner._read_attr(foreign_type)]
          end
        end
    end
  end
end
