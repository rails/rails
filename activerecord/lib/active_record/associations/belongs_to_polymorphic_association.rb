module ActiveRecord
  module Associations
    class BelongsToPolymorphicAssociation < AssociationProxy #:nodoc:
      def replace(record)
        if record.nil?
          @target = @owner[@reflection.primary_key_name] = @owner[@reflection.options[:foreign_type]] = nil
        else
          @target = (AssociationProxy === record ? record.target : record)

          unless record.new_record?
            @owner[@reflection.primary_key_name] = record.id
            @owner[@reflection.options[:foreign_type]] = record.class.base_class.name.to_s
          end

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
              :conditions => conditions,
              :include    => @reflection.options[:include]
            )
          else
            association_class.find(@owner[@reflection.primary_key_name], :include => @reflection.options[:include])
          end
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end

        def association_class
          @owner[@reflection.options[:foreign_type]] ? @owner[@reflection.options[:foreign_type]].constantize : nil
        end
    end
  end
end
