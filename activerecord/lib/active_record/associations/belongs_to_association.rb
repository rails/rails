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
        counter_cache_name = @reflection.counter_cache_column

        if record.nil?
          if counter_cache_name && !@owner.new_record?
            @reflection.klass.decrement_counter(counter_cache_name, @owner[@reflection.primary_key_name]) if @owner[@reflection.primary_key_name]
          end

          @target = @owner[@reflection.primary_key_name] = nil
        else
          raise_on_type_mismatch(record)

          if counter_cache_name && !@owner.new_record?
            @reflection.klass.increment_counter(counter_cache_name, record.id)
            @reflection.klass.decrement_counter(counter_cache_name, @owner[@reflection.primary_key_name]) if @owner[@reflection.primary_key_name]
          end

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
            :select     => @reflection.options[:select],
            :conditions => conditions,
            :include    => @reflection.options[:include],
            :readonly   => @reflection.options[:readonly]
          )
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end
    end
  end
end
