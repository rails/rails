# frozen_string_literal: true

module ActiveModel
  module Validations
    module Comparability # :nodoc:
      COMPARE_CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
        equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
        other_than: :!= }.freeze

      def error_options(value, option_value)
        options.except(*COMPARE_CHECKS.keys).merge!(
          count: option_value,
          value: value
        )
      end
    end
  end
end
