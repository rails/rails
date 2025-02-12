# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \DateTime \Type
    #
    # Attribute type to represent dates and times. It is registered under the
    # +:datetime+ key.
    #
    #   class Event
    #     include ActiveModel::Attributes
    #
    #     attribute :start, :datetime
    #   end
    #
    #   event = Event.new
    #   event.start = "Wed, 04 Sep 2013 03:00:00 EAT"
    #
    #   event.start.class # => Time
    #   event.start.year  # => 2013
    #   event.start.month # => 9
    #   event.start.day   # => 4
    #   event.start.hour  # => 3
    #   event.start.min   # => 0
    #   event.start.sec   # => 0
    #   event.start.zone  # => "EAT"
    #
    # String values are parsed using the ISO 8601 datetime format. Partial
    # time-only formats are also accepted.
    #
    #   event.start = "06:07:08+09:00"
    #   event.start.utc # => 1999-12-31 21:07:08 UTC
    #
    # The degree of sub-second precision can be customized when declaring an
    # attribute:
    #
    #   class Event
    #     include ActiveModel::Attributes
    #
    #     attribute :start, :datetime, precision: 4
    #   end
    class DateTime < Value
      include Helpers::Timezone
      include Helpers::AcceptsMultiparameterTime.new(
        defaults: { 4 => 0, 5 => 0 }
      )
      include Helpers::TimeValue

      def type
        :datetime
      end

      def mutable? # :nodoc:
        # Time#zone can be mutated by #utc or #localtime
        # However when serializing the time zone will always
        # be coerced and even if the zone was mutated Time instances
        # remain equal, so we don't need to implement `#changed_in_place?`
        true
      end

      private
        def cast_value(value)
          return apply_seconds_precision(value) unless value.is_a?(::String)
          return if value.empty?

          fast_string_to_time(value) || fallback_string_to_time(value)
        end

        # '0.123456' -> 123456
        # '1.123456' -> 123456
        def microseconds(time)
          time[:sec_fraction] ? (time[:sec_fraction] * 1_000_000).to_i : 0
        end

        def fallback_string_to_time(string)
          time_hash = begin
            ::Date._parse(string)
          rescue ArgumentError
          end
          return unless time_hash

          time_hash[:sec_fraction] = microseconds(time_hash)

          new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset))
        end

        def value_from_multiparameter_assignment(values_hash)
          missing_parameters = [1, 2, 3].delete_if { |key| values_hash.key?(key) }
          unless missing_parameters.empty?
            raise ArgumentError, "Provided hash #{values_hash} doesn't contain necessary keys: #{missing_parameters}"
          end
          super
        end
    end
  end
end
