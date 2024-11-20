# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Time \Type
    #
    # Attribute type for time of day representation. It is registered under the
    # +:time+ key.
    #
    #   class Event
    #     include ActiveModel::Attributes
    #
    #     attribute :start, :time
    #   end
    #
    # String values are parsed using the ISO 8601 datetime format, but are
    # normalized to have a date of 2000-01-01 and be in the UTC time zone.
    #
    #   event = Event.new
    #   event.start = "2004-10-25T01:23:45-06:00"
    #
    #   event.start.class # => Time
    #   event.start       # => 2000-01-01 07:23:45 UTC
    #
    # Partial time-only formats are also accepted.
    #
    #   event.start = "00:01:02+03:00"
    #   event.start # => 1999-12-31 21:01:02 UTC
    #
    # The degree of sub-second precision can be customized when declaring an
    # attribute:
    #
    #   class Event
    #     include ActiveModel::Attributes
    #
    #     attribute :start, :time, precision: 4
    #   end
    class Time < Value
      include Helpers::Timezone
      include Helpers::AcceptsMultiparameterTime.new(
        defaults: { 1 => 2000, 2 => 1, 3 => 1, 4 => 0, 5 => 0 }
      )
      include Helpers::TimeValue

      def type
        :time
      end

      def user_input_in_time_zone(value)
        return unless value.present?

        case value
        when ::String
          value = "2000-01-01 #{value}"
          time_hash = begin
            ::Date._parse(value)
          rescue ArgumentError
          end

          return if time_hash.nil? || time_hash[:hour].nil?
        when ::Time
          value = value.change(year: 2000, day: 1, month: 1)
        end

        super(value)
      end

      private
        def cast_value(value)
          return apply_seconds_precision(value) unless value.is_a?(::String)
          return if value.blank?

          dummy_time_value = value.sub(/\A\d{4}-\d\d-\d\d(?:T|\s)|/, "2000-01-01 ")

          fast_string_to_time(dummy_time_value) || begin
            time_hash = begin
              ::Date._parse(dummy_time_value)
            rescue ArgumentError
            end

            return if time_hash.nil? || time_hash[:hour].nil?
            new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset))
          end
        end
    end
  end
end
