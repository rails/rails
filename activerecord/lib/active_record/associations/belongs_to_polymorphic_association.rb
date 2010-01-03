module ActiveRecord
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

        set_inverse_instance(record, @owner)
        loaded
        record
      end

      def updated?
        @updated
      end

      private

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def we_can_set_the_inverse_on_this?(record)
          if @reflection.has_inverse?
            inverse_association = @reflection.polymorphic_inverse_of(record.class)
            inverse_association && inverse_association.macro == :has_one
          else
            false
          end
        end

        def set_inverse_instance(record, instance)
          return if record.nil? || !we_can_set_the_inverse_on_this?(record)
          inverse_relationship = @reflection.polymorphic_inverse_of(record.class)
          unless inverse_relationship.nil?
            record.send(:"set_#{inverse_relationship.name}_target", instance)
          end
        end

        def find_target
          return nil if association_class.nil?

          target =
            if @reflection.options[:conditions]
              association_class.find(
                @owner[@reflection.primary_key_name],
                :select     => @reflection.options[:select],
                :conditions => conditions,
                :include    => @reflection.options[:include]
              )
            else
              association_class.find(@owner[@reflection.primary_key_name], :select => @reflection.options[:select], :include => @reflection.options[:include])
            end
          set_inverse_instance(target, @owner)
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
