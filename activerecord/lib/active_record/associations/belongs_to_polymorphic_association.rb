module ActiveRecord
  # = Active Record Belongs To Polymorphic Association
  module Associations
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def klass
        type = owner[reflection.foreign_type]
        if type.presence
          if reflection.options[:class_name].is_a?(Proc)
            reflection.options[:class_name].call(type)
          else
            type.constantize
          end
        end
      end

      private

        def replace_keys(record)
          super
          owner[reflection.foreign_type] = record.class.sti_name
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
    end
  end
end
