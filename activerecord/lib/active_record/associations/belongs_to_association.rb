module ActiveRecord
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        replace(@reflection.klass.create(attributes))
      end

      def build(attributes = {})
        replace(@reflection.klass.new(attributes))
      end

      def replace(record)
        if record.nil?
          @target = @owner[@reflection.primary_key_name] = nil
        else
          raise_on_type_mismatch(record)

          @target = (AssociationProxy === record ? record.target : record)
          @owner[@reflection.primary_key_name] = record.id unless record.new_record?
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
          @reflection.klass.find(
            @owner[@reflection.primary_key_name], 
            :conditions => @reflection.options[:conditions] ? interpolate_sql(@reflection.options[:conditions]) : nil,
            :include    => @reflection.options[:include]
          )
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end
    end
  end
end
