# frozen_string_literal: true

module ActiveModel
  module Validations
    module Comparability # :nodoc:
      COMPARE_CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
        equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
        other_than: :!= }.freeze

      def option_value(record, option_value)
        case option_value
        when Proc
          option_value.call(record)
        when Symbol
          record.send(option_value)
        else
          option_value
        end
      end

      def error_options(value, option_value)
        options.except(*COMPARE_CHECKS.keys).merge!(
          count: option_value,
          value: value
        )
      end
    end
  end
end
