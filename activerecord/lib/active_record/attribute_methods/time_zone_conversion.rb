# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      class TimeZoneConverter < DelegateClass(Type::Value) # :nodoc:
        def self.new(subtype)
          self === subtype ? subtype : super
        end

        def deserialize(value)
          convert_time_to_time_zone(super)
        end

        def cast(value)
          return if value.nil?

          if value.is_a?(Hash)
            set_time_zone_without_conversion(super)
          elsif value.respond_to?(:in_time_zone)
            begin
              super(user_input_in_time_zone(value)) || super
            rescue ArgumentError
              nil
            end
          elsif value.respond_to?(:infinite?) && value.infinite?
            value
          else
            map_avoiding_infinite_recursion(super) { |v| cast(v) }
          end
        end

        def ==(other)
          other.is_a?(self.class) && __getobj__ == other.__getobj__
        end

        private
          def convert_time_to_time_zone(value)
            return if value.nil?

            if value.acts_like?(:time)
              value.in_time_zone
            elsif value.respond_to?(:infinite?) && value.infinite?
              value
            else
              map_avoiding_infinite_recursion(value) { |v| convert_time_to_time_zone(v) }
            end
          end

          def set_time_zone_without_conversion(value)
            ::Time.zone.local_to_utc(value).try(:in_time_zone) if value
          end

          def map_avoiding_infinite_recursion(value)
            map(value) do |v|
              if value.equal?(v)
                nil
              else
                yield(v)
              end
            end
          end
      end

      extend ActiveSupport::Concern

      included do
        class_attribute :time_zone_aware_attributes, instance_writer: false, default: false
        class_attribute :skip_time_zone_conversion_for_attributes, instance_writer: false, default: []
        class_attribute :time_zone_aware_types, instance_writer: false, default: [ :datetime, :time ]
      end

      module ClassMethods # :nodoc:
        def define_attribute(name, cast_type, **)
          if create_time_zone_conversion_attribute?(name, cast_type)
            cast_type = TimeZoneConverter.new(cast_type)
          end
          super
        end

        private
          def create_time_zone_conversion_attribute?(name, cast_type)
            enabled_for_column = time_zone_aware_attributes &&
              !skip_time_zone_conversion_for_attributes.include?(name.to_sym)

            enabled_for_column && time_zone_aware_types.include?(cast_type.type)
          end
      end
    end
  end
end
