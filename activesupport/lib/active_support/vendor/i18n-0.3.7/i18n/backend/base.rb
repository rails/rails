# encoding: utf-8

require 'yaml'
require 'i18n/core_ext/hash/except'

module I18n
  module Backend
    module Base
      include I18n::Backend::Helpers

      RESERVED_KEYS = [:scope, :default, :separator, :resolve]
      INTERPOLATION_SYNTAX_PATTERN = /(\\)?\{\{([^\}]+)\}\}/

      # Accepts a list of paths to translation files. Loads translations from
      # plain Ruby (*.rb) or YAML files (*.yml). See #load_rb and #load_yml
      # for details.
      def load_translations(*filenames)
        filenames.each { |filename| load_file(filename) }
      end

      # Stores translations for the given locale in memory.
      # This uses a deep merge for the translations hash, so existing
      # translations will be overwritten by new ones only at the deepest
      # level of the hash.
      def store_translations(locale, data, options = {})
        merge_translations(locale, data, options)
      end

      def translate(locale, key, options = {})
        raise InvalidLocale.new(locale) unless locale
        return key.map { |k| translate(locale, k, options) } if key.is_a?(Array)

        if options.empty?
          entry = resolve(locale, key, lookup(locale, key), options)
          raise(I18n::MissingTranslationData.new(locale, key, options)) if entry.nil?
        else
          count, scope, default = options.values_at(:count, :scope, :default)
          values = options.reject { |name, value| RESERVED_KEYS.include?(name) }

          entry = lookup(locale, key, scope, options)
          entry = entry.nil? && default ? default(locale, key, default, options) : resolve(locale, key, entry, options)
          raise(I18n::MissingTranslationData.new(locale, key, options)) if entry.nil?

          entry = pluralize(locale, entry, count)    if count
          entry = interpolate(locale, entry, values) if values
        end

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
          format = I18n.t(:"#{type}.formats.#{key}", :locale => locale, :raise => true)
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

      def initialized?
        @initialized ||= false
      end

      # Returns an array of locales for which translations are available
      # ignoring the reserved translation meta data key :i18n.
      def available_locales
        init_translations unless initialized?
        translations.inject([]) do |locales, (locale, data)|
          locales << locale unless (data.keys - [:i18n]).empty?
          locales
        end
      end

      def reload!
        @initialized = false
        @translations = nil
      end

      protected
        def init_translations
          load_translations(*I18n.load_path.flatten)
          @initialized = true
        end

        def translations
          @translations ||= {}
        end

        # Looks up a translation from the translations hash. Returns nil if
        # eiher key is nil, or locale, scope or key do not exist as a key in the
        # nested translations hash. Splits keys or scopes containing dots
        # into multiple keys, i.e. <tt>currency.format</tt> is regarded the same as
        # <tt>%w(currency format)</tt>.
        def lookup(locale, key, scope = [], options = {})
          return unless key
          init_translations unless initialized?
          keys = I18n.normalize_keys(locale, key, scope, options[:separator])
          keys.inject(translations) do |result, key|
            key = key.to_sym
            return nil unless result.is_a?(Hash) && result.has_key?(key)
            result = result[key]
            result = resolve(locale, key, result, options) if result.is_a?(Symbol)
            String === result ? result.dup : result
          end
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
            resolve(locale, object, subject.call(object, options), options = {})
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
          return entry unless entry.is_a?(Hash) and count

          key = :zero if count == 0 && entry.has_key?(:zero)
          key ||= count == 1 ? :one : :other
          raise InvalidPluralizationData.new(entry, count) unless entry.has_key?(key)
          entry[key]
        end

        # Interpolates values into a given string.
        #
        #   interpolate "file {{file}} opened by \\{{user}}", :file => 'test.txt', :user => 'Mr. X'
        #   # => "file test.txt opened by {{user}}"
        #
        # Note that you have to double escape the <tt>\\</tt> when you want to escape
        # the <tt>{{...}}</tt> key in a string (once for the string and once for the
        # interpolation).
        def interpolate(locale, string, values = {})
          return string unless string.is_a?(::String) && !values.empty?

          preserve_encoding(string) do
            s = string.gsub(INTERPOLATION_SYNTAX_PATTERN) do
              escaped, key = $1, $2.to_sym
              if escaped
                "{{#{key}}}"
              elsif RESERVED_KEYS.include?(key)
                raise ReservedInterpolationKey.new(key, string)
              else
                "%{#{key}}"
              end
            end

            values.each do |key, value|
              value = value.call(values) if interpolate_lambda?(value, s, key)
              value = value.to_s unless value.is_a?(::String)
              values[key] = value
            end

            s % values
          end

        rescue KeyError => e
          raise MissingInterpolationArgument.new(values, string)
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
          data.each { |locale, d| merge_translations(locale, d) }
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

        # Deep merges the given translations hash with the existing translations
        # for the given locale
        def merge_translations(locale, data, options = {})
          locale = locale.to_sym
          translations[locale] ||= {}
          separator = options[:separator] || I18n.default_separator
          data = unwind_keys(data, separator)
          data = deep_symbolize_keys(data)

          # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
          merger = proc do |key, v1, v2|
            # TODO should probably be:
            # raise TypeError.new("can't merge #{v1.inspect} and #{v2.inspect}") unless Hash === v1 && Hash === v2
            Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : (v2 || v1)
          end
          translations[locale].merge!(data, &merger)
        end
    end
  end
end
