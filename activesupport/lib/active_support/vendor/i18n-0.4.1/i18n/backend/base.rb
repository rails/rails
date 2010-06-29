# encoding: utf-8

require 'yaml'
require 'i18n/core_ext/hash'

module I18n
  module Backend
    module Base
      include I18n::Backend::Transliterator

      RESERVED_KEYS = [:scope, :default, :separator, :resolve]
      RESERVED_KEYS_PATTERN = /%\{(#{RESERVED_KEYS.join("|")})\}/
      DEPRECATED_INTERPOLATION_SYNTAX_PATTERN = /(\\)?\{\{([^\}]+)\}\}/
      INTERPOLATION_SYNTAX_PATTERN = /%\{([^\}]+)\}/

      # Accepts a list of paths to translation files. Loads translations from
      # plain Ruby (*.rb) or YAML files (*.yml). See #load_rb and #load_yml
      # for details.
      def load_translations(*filenames)
        filenames = I18n.load_path.flatten if filenames.empty?
        filenames.each { |filename| load_file(filename) }
      end

      # This method receives a locale, a data hash and options for storing translations.
      # Should be implemented
      def store_translations(locale, data, options = {})
        raise NotImplementedError
      end

      def translate(locale, key, options = {})
        raise InvalidLocale.new(locale) unless locale
        return key.map { |k| translate(locale, k, options) } if key.is_a?(Array)

        entry = key && lookup(locale, key, options[:scope], options)

        if options.empty?
          entry = resolve(locale, key, entry, options)
        else
          count, default = options.values_at(:count, :default)
          values = options.except(*RESERVED_KEYS)
          entry = entry.nil? && default ?
            default(locale, key, default, options) : resolve(locale, key, entry, options)
        end

        raise(I18n::MissingTranslationData.new(locale, key, options)) if entry.nil?
        entry = entry.dup if entry.is_a?(String)

        entry = pluralize(locale, entry, count) if count
        entry = interpolate(locale, entry, values) if values
        entry
      end

      # Acts the same as +strftime+, but uses a localized version of the
      # format string. Takes a key from the date/time formats translations as
      # a format argument (<em>e.g.</em>, <tt>:short</tt> in <tt>:'date.formats'</tt>).
      def localize(locale, object, format = :default, options = {})
        raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)

        if Symbol === format
          key = format
          type = object.respond_to?(:sec) ? 'time' : 'date'
          format = I18n.t(:"#{type}.formats.#{key}", options.merge(:raise => true, :object => object, :locale => locale))
        end

        # format = resolve(locale, object, format, options)
        format = format.to_s.gsub(/%[aAbBp]/) do |match|
          case match
          when '%a' then I18n.t(:"date.abbr_day_names",                  :locale => locale, :format => format)[object.wday]
          when '%A' then I18n.t(:"date.day_names",                       :locale => locale, :format => format)[object.wday]
          when '%b' then I18n.t(:"date.abbr_month_names",                :locale => locale, :format => format)[object.mon]
          when '%B' then I18n.t(:"date.month_names",                     :locale => locale, :format => format)[object.mon]
          when '%p' then I18n.t(:"time.#{object.hour < 12 ? :am : :pm}", :locale => locale, :format => format) if object.respond_to? :hour
          end
        end

        object.strftime(format)
      end

      # Returns an array of locales for which translations are available
      # ignoring the reserved translation meta data key :i18n.
      def available_locales
        raise NotImplementedError
      end

      def reload!
        @skip_syntax_deprecation = false
      end

      protected

        # The method which actually looks up for the translation in the store.
        def lookup(locale, key, scope = [], options = {})
          raise NotImplementedError
        end

        # Evaluates defaults.
        # If given subject is an Array, it walks the array and returns the
        # first translation that can be resolved. Otherwise it tries to resolve
        # the translation directly.
        def default(locale, object, subject, options = {})
          options = options.dup.reject { |key, value| key == :default }
          case subject
          when Array
            subject.each do |item|
              result = resolve(locale, object, item, options) and return result
            end and nil
          else
            resolve(locale, object, subject, options)
          end
        end

        # Resolves a translation.
        # If the given subject is a Symbol, it will be translated with the
        # given options. If it is a Proc then it will be evaluated. All other
        # subjects will be returned directly.
        def resolve(locale, object, subject, options = nil)
          return subject if options[:resolve] == false
          case subject
          when Symbol
            I18n.translate(subject, (options || {}).merge(:locale => locale, :raise => true))
          when Proc
            date_or_time = options.delete(:object) || object
            resolve(locale, object, subject.call(date_or_time, options), options = {})
          else
            subject
          end
        rescue MissingTranslationData
          nil
        end

        # Picks a translation from an array according to English pluralization
        # rules. It will pick the first translation if count is not equal to 1
        # and the second translation if it is equal to 1. Other backends can
        # implement more flexible or complex pluralization rules.
        def pluralize(locale, entry, count)
          return entry unless entry.is_a?(Hash) && count

          key = :zero if count == 0 && entry.has_key?(:zero)
          key ||= count == 1 ? :one : :other
          raise InvalidPluralizationData.new(entry, count) unless entry.has_key?(key)
          entry[key]
        end

        # Interpolates values into a given string.
        #
        #   interpolate "file %{file} opened by %%{user}", :file => 'test.txt', :user => 'Mr. X'
        #   # => "file test.txt opened by %{user}"
        #
        # Note that you have to double escape the <tt>\\</tt> when you want to escape
        # the <tt>{{...}}</tt> key in a string (once for the string and once for the
        # interpolation).
        def interpolate(locale, string, values = {})
          return string unless string.is_a?(::String) && !values.empty?
          original_values = values.dup

          preserve_encoding(string) do
            string = string.gsub(DEPRECATED_INTERPOLATION_SYNTAX_PATTERN) do
              escaped, key = $1, $2.to_sym
              if escaped
                "{{#{key}}}"
              else
                warn_syntax_deprecation!
                "%{#{key}}"
              end
            end

            keys = string.scan(INTERPOLATION_SYNTAX_PATTERN).flatten
            return string if keys.empty?

            values.each do |key, value|
              if keys.include?(key.to_s)
                value = value.call(values) if interpolate_lambda?(value, string, key)
                value = value.to_s unless value.is_a?(::String)
                values[key] = value
              else
                values.delete(key)
              end
            end

            string % values
          end
        rescue KeyError => e
          if string =~ RESERVED_KEYS_PATTERN
            raise ReservedInterpolationKey.new($1.to_sym, string)
          else
            raise MissingInterpolationArgument.new(original_values, string)
          end
        end

        def preserve_encoding(string)
          if string.respond_to?(:encoding)
            encoding = string.encoding
            result = yield
            result.force_encoding(encoding) if result.respond_to?(:force_encoding)
            result
          else
            yield
          end
        end

        # returns true when the given value responds to :call and the key is
        # an interpolation placeholder in the given string
        def interpolate_lambda?(object, string, key)
          object.respond_to?(:call) && string =~ /%\{#{key}\}|%\<#{key}>.*?\d*\.?\d*[bBdiouxXeEfgGcps]\}/
        end

        # Loads a single translations file by delegating to #load_rb or
        # #load_yml depending on the file extension and directly merges the
        # data to the existing translations. Raises I18n::UnknownFileType
        # for all other file extensions.
        def load_file(filename)
          type = File.extname(filename).tr('.', '').downcase
          raise UnknownFileType.new(type, filename) unless respond_to?(:"load_#{type}")
          data = send(:"load_#{type}", filename) # TODO raise a meaningful exception if this does not yield a Hash
          data.each { |locale, d| store_translations(locale, d) }
        end

        # Loads a plain Ruby translations file. eval'ing the file must yield
        # a Hash containing translation data with locales as toplevel keys.
        def load_rb(filename)
          eval(IO.read(filename), binding, filename)
        end

        # Loads a YAML translations file. The data must have locales as
        # toplevel keys.
        def load_yml(filename)
          YAML::load(IO.read(filename))
        end

        def warn_syntax_deprecation! #:nodoc:
          return if @skip_syntax_deprecation
          warn "The {{key}} interpolation syntax in I18n messages is deprecated. Please use %{key} instead.\n#{caller.join("\n")}"
          @skip_syntax_deprecation = true
        end
    end
  end
end
