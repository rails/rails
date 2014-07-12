module ActiveSupport
  module NumberHelper
    class NumberToCurrencyConverter < NumberConverter # :nodoc:
      self.namespace = :currency

      def convert
        number = self.number.to_s.strip
        format = options[:format]

        if is_negative?(number)
          format = options[:negative_format]
          number = absolute_value(number)
        end

        rounded_number = NumberToRoundedConverter.convert(number, options)
        format.gsub('%n', rounded_number).gsub('%u', options[:unit])
      end

      private

        def is_negative?(number)
          number.to_f.phase != 0
        end

        def absolute_value(number)
          number.respond_to?("abs") ? number.abs : number.sub(/\A-/, '')
        end

        def options
          @options ||= begin
            defaults = default_format_options.merge(i18n_opts)
            # Override negative format if format options is given
            defaults[:negative_format] = "-#{opts[:format]}" if opts[:format]
            defaults.merge!(opts)
          end
        end

        def i18n_opts
          # Set International negative format if not exists
          i18n = i18n_format_options
          i18n[:negative_format] ||= "-#{i18n[:format]}" if i18n[:format]
          i18n
        end
    end
  end
end
