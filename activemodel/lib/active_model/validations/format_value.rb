# frozen_string_literal: true

module ActiveModel
  module Validations
    module FormatValue # :nodoc:
      def format_value(record, value)
        value_format = options[:value_format]

        case value_format
        when Proc
          value_format.call(value)
        when Symbol
          record.send(value_format, value)
        else
          if value_format.respond_to?(:call)
            value_format.call(value)
          else
            value
          end
        end
      end
    end
  end
end
