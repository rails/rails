module ActiveRecord
  # = Active Record Belongs To Polymorphic Association
  module Associations
    class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:
      def stale_target?
        if @target && @target.persisted?
          target_id    = @target.send(@reflection.association_primary_key).to_s
          foreign_key  = @owner.send(@reflection.primary_key_name).to_s
          target_type  = @target.class.base_class.name
          foreign_type = @owner.send(@reflection.options[:foreign_type]).to_s

          target_id != foreign_key || target_type != foreign_type
        else
          false
        end
      end

      private

        def replace_keys(record)
          super
          @owner[@reflection.options[:foreign_type]] = record && record.class.base_class.name
        end

        def different_target?(record)
          super || record.class != target_klass
        end

        def inverse_reflection_for(record)
          @reflection.polymorphic_inverse_of(record.class)
        end

        def target_klass
          type = @owner[@reflection.options[:foreign_type]]
          type && type.constantize
        end

        def raise_on_type_mismatch(record)
          # A polymorphic association cannot have a type mismatch, by definition
        end
    end
  end
end
