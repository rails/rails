require 'active_support/number_helper/number_converter'
require 'active_support/number_helper/number_to_rounded'

module ActiveSupport
  module NumberHelper
    class NumberToPercentageConverter < NumberConverter # :nodoc:

      self.namespace = :percentage

      def convert
        rounded_number = NumberToRoundedConverter.new(number, options).execute
        options[:format].gsub('%n', rounded_number)
      end

    end
  end
end
