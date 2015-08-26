module ActiveSupport
  module NumberHelper
    class NumberToDelimitedConverter < NumberConverter #:nodoc:
      self.validate_float = true

      def convert
        parts.join(options[:separator])
      end

      private

        def parts
          left, right = number.to_s.split('.')

          left.gsub!(options[:format_mask_regex]) do |digit_to_delimit|
            "#{digit_to_delimit}#{options[:delimiter]}"
          end

          [left, right].compact
        end
    end
  end
end
