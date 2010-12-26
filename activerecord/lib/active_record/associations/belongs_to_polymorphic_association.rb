module ActiveRecord
  # = Active Record Belongs To Polymorphic Association
  module Associations
    class BelongsToPolymorphicAssociation < AssociationProxy #:nodoc:
      def replace(record)
        if record.nil?
          @target = @owner[@reflection.primary_key_name] = @owner[@reflection.options[:foreign_type]] = nil
        else
          @target = (AssociationProxy === record ? record.target : record)

          @owner[@reflection.primary_key_name] = record_id(record)
          @owner[@reflection.options[:foreign_type]] = record.class.base_class.name.to_s

          @updated = true
        end

        set_inverse_instance(record)
        loaded
        record
      end

      def updated?
        @updated
      end

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

        def inverse_reflection_for(record)
          @reflection.polymorphic_inverse_of(record.class)
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && inverse.macro == :has_one
        end

        def construct_find_scope
          { :conditions => conditions }
        end

        def find_target
          return nil if association_class.nil?

          target = association_class.send(:with_scope, :find => @scope[:find]) do
            association_class.find(
              @owner[@reflection.primary_key_name],
              :select  => @reflection.options[:select],
              :include => @reflection.options[:include]
            )
          end
          set_inverse_instance(target)
          target
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end

        def record_id(record)
          record.send(@reflection.options[:primary_key] || :id)
        end

        def association_class
          @owner[@reflection.options[:foreign_type]] ? @owner[@reflection.options[:foreign_type]].constantize : nil
        end
    end
  end
end
