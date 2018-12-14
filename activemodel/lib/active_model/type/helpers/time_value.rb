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
          round_power = 10**number_of_insignificant_digits
          value.change(usec: value.usec - value.usec % round_power)
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

          # Does not handle time zone offsets with minute offsets due to performance
          ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?([+-]\d\d(?::?00)?)?\z/

          def fast_string_to_time(string)
            if string =~ ISO_DATETIME
              microsec = parse_microseconds($7)
              offset = parse_offset($8)
              new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec, offset
            end
          end

          def parse_microseconds(microsec_part)
            if microsec_part && microsec_part.start_with?(".") && microsec_part.length == 7
              microsec_part[0] = ""
              microsec_part.to_i
            else
              (microsec_part.to_r * 1_000_000).to_i
            end
          end

          def parse_offset(offset_part)
            if offset_part
              offset_part.to_i * 3600
            else
              nil
            end
          end
      end
    end
  end
end
