# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class TimestampWithTimeZone < Timestamp # :nodoc:
          def type
            :timestamptz
          end
        end
      end
    end
  end
end
