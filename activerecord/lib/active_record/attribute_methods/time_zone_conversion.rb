require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/inclusion'

module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      extend ActiveSupport::Concern

      included do
        cattr_accessor :time_zone_aware_attributes, :instance_writer => false
        self.time_zone_aware_attributes = false

        class_attribute :skip_time_zone_conversion_for_attributes, :instance_writer => false
        self.skip_time_zone_conversion_for_attributes = []
      end

      module ClassMethods
        protected
          # Defined for all +datetime+ and +timestamp+ attributes when +time_zone_aware_attributes+ are enabled.
          # This enhanced read method automatically converts the UTC time stored in the database to the time
          # zone stored in Time.zone.
          def define_method_attribute(attr_name)
            if create_time_zone_conversion_attribute?(attr_name, columns_hash[attr_name])
              method_body, line = <<-EOV, __LINE__ + 1
                def _#{attr_name}
                  cached = @attributes_cache['#{attr_name}']
                  return cached if cached
                  time = _read_attribute('#{attr_name}')
                  @attributes_cache['#{attr_name}'] = time.acts_like?(:time) ? time.in_time_zone : time
                end
                alias #{attr_name} _#{attr_name}
              EOV
              generated_attribute_methods.module_eval(method_body, __FILE__, line)
            else
              super
            end
          end

          # Defined for all +datetime+ and +timestamp+ attributes when +time_zone_aware_attributes+ are enabled.
          # This enhanced write method will automatically convert the time passed to it to the zone stored in Time.zone.
          def define_method_attribute=(attr_name)
            if create_time_zone_conversion_attribute?(attr_name, columns_hash[attr_name])
              method_body, line = <<-EOV, __LINE__ + 1
                def #{attr_name}=(original_time)
                  time = original_time
                  unless time.acts_like?(:time)
                    time = time.is_a?(String) ? Time.zone.parse(time) : time.to_time rescue time
                  end
                  time = time.in_time_zone rescue nil if time
                  write_attribute(:#{attr_name}, original_time)
                  @attributes_cache["#{attr_name}"] = time
                end
              EOV
              generated_attribute_methods.module_eval(method_body, __FILE__, line)
            else
              super
            end
          end

        private
          def create_time_zone_conversion_attribute?(name, column)
            time_zone_aware_attributes && !self.skip_time_zone_conversion_for_attributes.include?(name.to_sym) && column.type.in?([:datetime, :timestamp])
          end
      end
    end
  end
end
