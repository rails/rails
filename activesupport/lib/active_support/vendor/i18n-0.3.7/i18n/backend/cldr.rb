# encoding: utf-8
require 'cldr'

module I18n
  module Backend
    module Cldr
      include ::Cldr::Format

      def localize(locale, object, format = :default, options = {})
        options[:as] ||= detect_type(object, options)
        send(:"format_#{options[:as]}", locale, object, format, options)
      end

      def format_decimal(locale, object, format = :default, options = {})
        formatter(locale, :decimal, format).apply(object, options)
      end

      def format_integer(locale, object, format = :default, options = {})
        format_object(number, options.merge(:precision => 0))
      end

      def format_currency(locale, object, format = :default, options = {})
        options.merge!(:currency => lookup_currency(locale, options[:currency], object)) if options[:currency].is_a?(Symbol)
        formatter(locale, :currency, format).apply(object, options)
      end

      def format_percent(locale, object, format = :default, options = {})
        formatter(locale, :percent, format).apply(object, options)
      end

      def format_date(locale, object, format = :default, options = {})
        formatter(locale, :date, format).apply(object, options)
      end

      def format_time(locale, object, format = :default, options = {})
        formatter(locale, :time, format).apply(object, options)
      end

      def format_datetime(locale, object, format = :default, options = {})
        key  = :"calendars.gregorian.formats.datetime.#{format}.pattern"
        date = I18n.l(object, :format => options[:date_format] || format, :locale => locale, :as => :date)
        time = I18n.l(object, :format => options[:time_format] || format, :locale => locale, :as => :time)
        I18n.t(key, :date => date, :time => time, :locale => locale, :raise => true)
      end

      protected

        def detect_type(object, options)
          options.has_key?(:currency) ? :currency : case object
          when ::Numeric
            :decimal
          when ::Date, ::DateTime, ::Time
            object.class.name.downcase.to_sym
          else
            raise_unspecified_format_type!
          end
        end

        def formatter(locale, type, format)
          (@formatters ||= {})[:"#{locale}.#{type}.#{format}"] ||= begin
            format = lookup_format(locale, type, format)
            data   = lookup_format_data(locale, type)
            ::Cldr::Format.const_get(type.to_s.camelize).new(format, data)
          end
        end

        def lookup_format(locale, type, format)
          key = case type
          when :date, :time, :datetime
            :"calendars.gregorian.formats.#{type}.#{format}.pattern"
          else
            :"numbers.formats.#{type}.patterns.#{format || :default}"
          end
          I18n.t(key, :locale => locale, :raise => true)
        end

        def lookup_format_data(locale, type)
          key = case type
          when :date, :time, :datetime
            :'calendars.gregorian'
          else
            :'numbers.symbols'
          end
          I18n.t(key, :locale => locale, :raise => true)
        end

        def lookup_currency(locale, currency, count)
          I18n.t(:"currencies.#{currency}", :locale => locale, :count => count)
        end

        def raise_unspecified_format_type!
          raise ArgumentError.new("You have to specify a format type, e.g. :as => :number.")
        end

        def raise_unspecified_currency!
          raise ArgumentError.new("You have to specify a currency, e.g. :currency => 'EUR'.")
        end
    end
  end
end