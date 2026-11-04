# frozen_string_literal: true

require "active_support/duration"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Interval < Type::Value # :nodoc:
          def type
            :interval
          end

          def cast_value(value)
            case value
            when ::ActiveSupport::Duration
              value
            when ::String
              begin
                ::ActiveSupport::Duration.parse(value)
              rescue ::ActiveSupport::Duration::ISO8601Parser::ParsingError
                nil
              end
            else
              super
            end
          end

          def serialize(value)
            case value
            when ::ActiveSupport::Duration
              value.iso8601(precision: self.precision)
            when ::Numeric
              # Sometimes operations on Times returns just float number of seconds so we need to handle that.
              # Example: Time.current - (Time.current + 1.hour) # => -3600.000001776 (Float)
              ActiveSupport::Duration.build(value).iso8601(precision: self.precision)
            else
              super
            end
          end

          def type_cast_for_schema(value)
            serialize(value).inspect
          end
        end
      end
    end
  end
end
