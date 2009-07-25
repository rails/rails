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

        loaded
        record
      end

      def updated?
        @updated
      end

      private
        def find_target
          return nil if association_class.nil?

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
