# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Duration \Type
    #
    # Attribute type for ActiveSupport::Duration representation. It is registered under the
    # +:duration+ key.
    #
    #   class Run
    #     include ActiveModel::Attributes
    #
    #     attribute :lasted, :duration
    #   end
    #
    #   run = Run.new
    #   run.lasted = 2.hours
    #
    # Integer values are parsed as seconds.
    #
    #   run = Run.new
    #   run.lasted = 120
    #
    #   run.lasted.class # => ActiveSupport::Duration
    #   run.lasted       # => 2 hours
    #
    # String values are parsed using the ISO 8601 duration format.
    #
    #   run = Run.new
    #   run.lasted = "PT2H"
    #
    #   run.lasted.class # => ActiveSupport::Duration
    #   run.lasted       # => 2 hours
    #
    # The degree of sub-second precision can be customized when declaring an
    # attribute:
    #
    #   class Run
    #     include ActiveModel::Attributes
    #
    #     attribute :lasted, :duration, precision: 4
    #   end
    class Duration < Value
      def cast_value(value)
        case value
        when ::ActiveSupport::Duration
          value
        when ::Numeric
          value.seconds
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
          value.seconds.iso8601(precision: self.precision)
        else
          super
        end
      end
    end
  end
end
