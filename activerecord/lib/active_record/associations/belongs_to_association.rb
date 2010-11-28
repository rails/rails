module ActiveRecord
  # = Active Record Belongs To Associations
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        replace(@reflection.create_association(attributes))
      end

      def build(attributes = {})
        replace(@reflection.build_association(attributes))
      end

      def replace(record)
        counter_cache_name = @reflection.counter_cache_column

        if record.nil?
          if counter_cache_name && !@owner.new_record?
            @reflection.klass.decrement_counter(counter_cache_name, previous_record_id) if @owner[@reflection.primary_key_name]
          end

          @target = @owner[@reflection.primary_key_name] = nil
        else
          raise_on_type_mismatch(record)

          if counter_cache_name && !@owner.new_record? && record.id != @owner[@reflection.primary_key_name]
            @reflection.klass.increment_counter(counter_cache_name, record.id)
            @reflection.klass.decrement_counter(counter_cache_name, @owner[@reflection.primary_key_name]) if @owner[@reflection.primary_key_name]
          end

          @target = (AssociationProxy === record ? record.target : record)
          @owner[@reflection.primary_key_name] = record_id(record) unless record.new_record?
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
        def find_target
          find_method = if @reflection.options[:primary_key]
                          "find_by_#{@reflection.options[:primary_key]}"
                        else
                          "find"
                        end

          options = @reflection.options.dup
          (options.keys - [:select, :include, :readonly]).each do |key|
            options.delete key
          end
          options[:conditions] = conditions

          the_target = @reflection.klass.send(find_method,
            @owner[@reflection.primary_key_name],
            options
          ) if @owner[@reflection.primary_key_name]
          set_inverse_instance(the_target, @owner)
          the_target
        end

        def foreign_key_present
          !@owner[@reflection.primary_key_name].nil?
        end

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def we_can_set_the_inverse_on_this?(record)
          @reflection.has_inverse? && @reflection.inverse_of.macro == :has_one
        end

        def record_id(record)
          record.send(@reflection.options[:primary_key] || :id)
        end

        def previous_record_id
          @previous_record_id ||= if @reflection.options[:primary_key]
                                    previous_record = @owner.send(@reflection.name)
                                    previous_record.nil? ? nil : previous_record.id
                                  else
                                    @owner[@reflection.primary_key_name]
                                  end
        end
    end
  end
end
