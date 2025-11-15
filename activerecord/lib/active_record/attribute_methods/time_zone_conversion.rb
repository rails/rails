# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      class TimeZoneConverter # :nodoc:
        def self.new(subtype)
          self === subtype ? subtype : super
        end

        def initialize(subtype)
          @subtype = subtype
        end

        def deserialize(value)
          convert_time_to_time_zone(@subtype.deserialize(value))
        end

        def cast(value)
          return if value.nil?

          if value.is_a?(Hash)
            set_time_zone_without_conversion(@subtype.cast(value))
          elsif value.respond_to?(:in_time_zone)
            begin
              result = @subtype.cast(@subtype.user_input_in_time_zone(value)) || @subtype.cast(value)
              if result && type == :time
                result = result.change(year: 2000, month: 1, day: 1)
              end
              result
            rescue ArgumentError
              nil
            end
          elsif value.respond_to?(:infinite?) && value.infinite?
            value
          else
            map(@subtype.cast(value)) { |v| cast(v) }
          end
        end

        def ==(other)
          other.is_a?(self.class) && @subtype == other.__getobj__
        end

        def __getobj__
          @subtype
        end

        delegate *(Type::Value.public_instance_methods - public_instance_methods), to: :@subtype

        private
          def convert_time_to_time_zone(value)
            return if value.nil?

            if value.acts_like?(:time)
              converted = value.in_time_zone
              if type == :time && converted
                converted = converted.change(year: 2000, month: 1, day: 1)
              end
              converted
            elsif value.respond_to?(:infinite?) && value.infinite?
              value
            else
              map(value) { |v| convert_time_to_time_zone(v) }
            end
          end

          def set_time_zone_without_conversion(value)
            ::Time.zone.local_to_utc(value).try(:in_time_zone) if value
          end
      end

      extend ActiveSupport::Concern

      included do
        class_attribute :time_zone_aware_attributes, instance_writer: false, default: false
        class_attribute :skip_time_zone_conversion_for_attributes, instance_writer: false, default: []
        class_attribute :time_zone_aware_types, instance_writer: false, default: [ :datetime, :time ]
      end

      module ClassMethods # :nodoc:
        private
          def hook_attribute_type(name, cast_type)
            if create_time_zone_conversion_attribute?(name, cast_type)
              cast_type = TimeZoneConverter.new(cast_type)
            end

            super
          end

          def create_time_zone_conversion_attribute?(name, cast_type)
            enabled_for_column = time_zone_aware_attributes &&
              !skip_time_zone_conversion_for_attributes.include?(name.to_sym)

            enabled_for_column && time_zone_aware_types.include?(cast_type.type)
          end
      end
    end
  end
end
