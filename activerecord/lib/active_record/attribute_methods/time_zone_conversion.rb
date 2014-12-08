module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      class TimeZoneConverter < DelegateClass(Type::Value) # :nodoc:
        include Type::Decorator

        def type_cast_from_database(value)
          convert_time_to_time_zone(super)
        end

        def type_cast_from_user(value)
          if value.is_a?(Array)
            value.map { |v| type_cast_from_user(v) }
          elsif value.respond_to?(:in_time_zone)
            value.in_time_zone || super
          end
        end

        def convert_time_to_time_zone(value)
          if value.is_a?(Array)
            value.map { |v| convert_time_to_time_zone(v) }
          elsif value.acts_like?(:time)
            value.in_time_zone
          else
            value
          end
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
        private

        def inherited(subclass)
          # We need to apply this decorator here, rather than on module inclusion. The closure
          # created by the matcher would otherwise evaluate for `ActiveRecord::Base`, not the
          # sub class being decorated. As such, changes to `time_zone_aware_attributes`, or
          # `skip_time_zone_conversion_for_attributes` would not be picked up.
          subclass.class_eval do
            matcher = ->(name, type) { create_time_zone_conversion_attribute?(name, type) }
            decorate_matching_attribute_types(matcher, :_time_zone_conversion) do |type|
              TimeZoneConverter.new(type)
            end
          end
          super
        end

        def create_time_zone_conversion_attribute?(name, cast_type)
          time_zone_aware_attributes &&
            !self.skip_time_zone_conversion_for_attributes.include?(name.to_sym) &&
            (:datetime == cast_type.type)
        end
      end
    end
  end
end
