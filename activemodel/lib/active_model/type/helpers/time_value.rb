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
            if is_utc?
              value = value.getutc if !value.utc?
            else
              value = value.getlocal
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
          value.to_fs(:db).inspect
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

              time -= offset unless offset == 0
              is_utc? ? time : time.getlocal
            elsif is_utc?
              ::Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
            else
              ::Time.local(year, mon, mday, hour, min, sec, microsec) rescue nil
            end
          end

          ISO_DATETIME = /
            \A
            (\d{4})-(\d\d)-(\d\d)(?:T|\s)            # 2020-06-20T
            (\d\d):(\d\d):(\d\d)(?:\.(\d{1,6})\d*)?  # 10:20:30.123456
            (?:(Z(?=\z)|[+-]\d\d)(?::?(\d\d))?)?     # +09:00
            \z
          /x

          def fast_string_to_time(string)
            return unless ISO_DATETIME =~ string

            usec = $7.to_i
            usec_len = $7&.length
            if usec_len&.< 6
              usec *= 10**(6 - usec_len)
            end

            if $8
              offset = $8 == "Z" ? 0 : $8.to_i * 3600 + $9.to_i * 60
            end

            new_time($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, usec, offset)
          end
      end
    end
  end
end
