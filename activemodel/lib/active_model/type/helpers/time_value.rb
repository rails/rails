require "active_support/core_ext/time/zones"

module ActiveModel
  module Type
    module Helpers
      module TimeValue # :nodoc:
        def serialize(value)
          value = apply_seconds_precision(value)

          if value.acts_like?(:time)
            zone_conversion_method = is_utc? ? :getutc : :getlocal

            if value.respond_to?(zone_conversion_method)
              value = value.send(zone_conversion_method)
            end
          end

          value
        end

        def is_utc?
          ::Time.zone_default.nil? || ::Time.zone_default =~ "UTC"
        end

        def default_timezone
          if is_utc?
            :utc
          else
            :local
          end
        end

        def apply_seconds_precision(value)
          return value unless precision && value.respond_to?(:usec)
          number_of_insignificant_digits = 6 - precision
          round_power = 10 ** number_of_insignificant_digits
          value.change(usec: value.usec / round_power * round_power)
        end

        def type_cast_for_schema(value)
          "'#{value.to_s(:db)}'"
        end

        def user_input_in_time_zone(value)
          value.in_time_zone
        end

        private

          def new_time(year, mon, mday, hour, min, sec, microsec, offset = nil)
            # Treat 0000-00-00 00:00:00 as nil.
            return if year.nil? || (year == 0 && mon == 0 && mday == 0)

            if offset
              time = ::Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
              return unless time

              time -= offset
              is_utc? ? time : time.getlocal
            else
              ::Time.public_send(default_timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
            end
          end

          ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/

        # Doesn't handle time zones.
          def fast_string_to_time(string)
            if string =~ ISO_DATETIME
              microsec = ($7.to_r * 1_000_000).to_i
              new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
            end
          end
      end
    end
  end
end
