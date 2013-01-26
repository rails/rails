module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      class Type # :nodoc:
        def initialize(column)
          @column = column
        end

        def type_cast(value)
          value = @column.type_cast(value)
          value.acts_like?(:time) ? value.in_time_zone : value
        end

        def type
          @column.type
        end
      end

      extend ActiveSupport::Concern

      included do
        mattr_accessor :time_zone_aware_attributes, instance_writer: false
        self.time_zone_aware_attributes = false

        class_attribute :skip_time_zone_conversion_for_attributes, instance_writer: false
        self.skip_time_zone_conversion_for_attributes = []
      end

      module ClassMethods
        protected
        # Defined for all +datetime+ and +timestamp+ attributes when +time_zone_aware_attributes+ are enabled.
        # This enhanced write method will automatically convert the time passed to it to the zone stored in Time.zone.
        def define_method_attribute=(attr_name)
          if create_time_zone_conversion_attribute?(attr_name, columns_hash[attr_name])
            method_body, line = <<-EOV, __LINE__ + 1
              def #{attr_name}=(time)
                time_with_zone = time.respond_to?(:in_time_zone) ? time.in_time_zone : nil
                previous_time = attribute_changed?("#{attr_name}") ? changed_attributes["#{attr_name}"] : read_attribute(:#{attr_name})
                write_attribute(:#{attr_name}, time)
                #{attr_name}_will_change! if previous_time != time_with_zone
                @attributes_cache["#{attr_name}"] = time_with_zone
              end
            EOV
            generated_attribute_methods.module_eval(method_body, __FILE__, line)
          else
            super
          end
        end

        private
        def create_time_zone_conversion_attribute?(name, column)
          time_zone_aware_attributes &&
            !self.skip_time_zone_conversion_for_attributes.include?(name.to_sym) &&
            [:datetime, :timestamp].include?(column.type)
        end
      end
    end
  end
end
