# frozen_string_literal: true

require "active_support/number_helper/number_converter"

module ActiveSupport
  module NumberHelper
    class NumberToCurrencyConverter < NumberConverter # :nodoc:
      self.namespace = :currency

      def convert
        number = self.number.to_s.strip
        format = options[:format]

        if number.sub!(/^-/, "")
          number_f = number.to_f.abs
          if number_f == 0.0
            # likely an alternate input format that failed to parse.
            # see https://github.com/rails/rails/pull/39350
            format = options[:negative_format]
          else
            number_f *= 10**options[:precision]
            format = options[:negative_format] if number_f >= 0.5
          end
        end

        rounded_number = NumberToRoundedConverter.convert(number, options)
        format.gsub("%n", rounded_number).gsub("%u", options[:unit])
      end

      private
        def options
          @options ||= begin
            defaults = default_format_options.merge(i18n_opts)
            # Override negative format if format options are given
            defaults[:negative_format] = "-#{opts[:format]}" if opts[:format]
            defaults.merge!(opts)
          end
        end

        def i18n_opts
          # Set International negative format if it does not exist
          i18n = i18n_format_options
          i18n[:negative_format] ||= "-#{i18n[:format]}" if i18n[:format]
          i18n
        end
    end
  end
end
