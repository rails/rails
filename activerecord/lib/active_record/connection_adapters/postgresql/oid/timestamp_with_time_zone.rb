# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class TimestampWithTimeZone < DateTime # :nodoc:
          def type
            real_type_unless_aliased(:timestamptz)
          end

          def cast_value(value)
            return if value.blank?

            time = super
            return time if time.is_a?(ActiveSupport::TimeWithZone) || !time.acts_like?(:time)

            # While in UTC mode, the PG gem may not return times back in "UTC" even if they were provided to Postgres in UTC.
            # We prefer times always in UTC, so here we convert back.
            if is_utc?
              time.getutc
            else
              time.getlocal
            end
          end
        end
      end
    end
  end
end
