# frozen_string_literal: true

require "active_support/core_ext/string/zones"
require "active_support/core_ext/time/zones"

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module TimeValue
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

        def apply_seconds_precision(value)
          return value unless precision && value.respond_to?(:nsec)

          number_of_insignificant_digits = 9 - precision
          round_power = 10**number_of_insignificant_digits
          rounded_off_nsec = value.nsec % round_power

          if rounded_off_nsec > 0
            value.change(nsec: value.nsec - rounded_off_nsec)
          else
            value
          end
        end

        def type_cast_for_schema(value)
          value.to_s(:db).inspect
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
              microsec_part = $7
              if microsec_part && microsec_part.start_with?(".") && microsec_part.length == 7
                microsec_part[0] = ""
                microsec = microsec_part.to_i
              else
                microsec = (microsec_part.to_r * 1_000_000).to_i
              end
              new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
            end
          end
      end
    end
  end
end
