# frozen_string_literal: true

module ActiveSupport
  module NumberHelper
    class NumberToPercentageConverter < NumberConverter # :nodoc:
      self.namespace = :percentage

      def convert(number = self.number)
        rounded_number = number_to_rounded_converter.execute(number)
        options[:format].gsub("%n".freeze, rounded_number)
      end

      private

        def number_to_rounded_converter
          @number_to_rounded_converter ||= NumberToRoundedConverter.new(options)
        end
    end
  end
end
