require 'i18n/exceptions'

module I18n
  module Backend
    class Simple
      INTERPOLATION_RESERVED_KEYS = %w(scope default)
      MATCH = /(\\\\)?\{\{([^\}]+)\}\}/

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
      def store_translations(locale, data)
        merge_translations(locale, data)
      end

      def translate(locale, key, options = {})
        raise InvalidLocale.new(locale) if locale.nil?
        return key.map { |k| translate(locale, k, options) } if key.is_a? Array

        reserved = :scope, :default
        count, scope, default = options.values_at(:count, *reserved)
        options.delete(:default)
        values = options.reject { |name, value| reserved.include?(name) }

        entry = lookup(locale, key, scope)
        if entry.nil?
          entry = default(locale, default, options)
          if entry.nil?
            raise(I18n::MissingTranslationData.new(locale, key, options))
          end
        end
        entry = pluralize(locale, entry, count)
        entry = interpolate(locale, entry, values)
        entry
      end

      # Acts the same as +strftime+, but returns a localized version of the
      # formatted date string. Takes a key from the date/time formats
      # translations as a format argument (<em>e.g.</em>, <tt>:short</tt> in <tt>:'date.formats'</tt>).
      def localize(locale, object, format = :default)
        raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)

        type = object.respond_to?(:sec) ? 'time' : 'date'
        # TODO only translate these if format is a String?
        formats = translate(locale, :"#{type}.formats")
        format = formats[format.to_sym] if formats && formats[format.to_sym]
        # TODO raise exception unless format found?
        format = format.to_s.dup

        # TODO only translate these if the format string is actually present
        # TODO check which format strings are present, then bulk translate then, then replace them
        format.gsub!(/%a/, translate(locale, :"date.abbr_day_names")[object.wday])
        format.gsub!(/%A/, translate(locale, :"date.day_names")[object.wday])
        format.gsub!(/%b/, translate(locale, :"date.abbr_month_names")[object.mon])
        format.gsub!(/%B/, translate(locale, :"date.month_names")[object.mon])
        format.gsub!(/%p/, translate(locale, :"time.#{object.hour < 12 ? :am : :pm}")) if object.respond_to? :hour
        object.strftime(format)
      end

      def initialized?
        @initialized ||= false
      end

      # Returns an array of locales for which translations are available
      def available_locales
        init_translations unless initialized?
        translations.keys
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
        def lookup(locale, key, scope = [])
          return unless key
          init_translations unless initialized?
          keys = I18n.send(:normalize_translation_keys, locale, key, scope)
          keys.inject(translations) do |result, k|
            if (x = result[k.to_sym]).nil?
              return nil
            else
              x
            end
          end
        end

        # Evaluates a default translation.
        # If the given default is a String it is used literally. If it is a Symbol
        # it will be translated with the given options. If it is an Array the first
        # translation yielded will be returned.
        #
        # <em>I.e.</em>, <tt>default(locale, [:foo, 'default'])</tt> will return +default+ if
        # <tt>translate(locale, :foo)</tt> does not yield a result.
        def default(locale, default, options = {})
          case default
            when String then default
            when Symbol then translate locale, default, options
            when Array  then default.each do |obj|
              result = default(locale, obj, options.dup) and return result
            end and nil
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
          # raise InvalidPluralizationData.new(entry, count) unless entry.is_a?(Hash)
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
          return string unless string.is_a?(String)

          string.gsub(MATCH) do
            escaped, pattern, key = $1, $2, $2.to_sym

            if escaped
              pattern
            elsif INTERPOLATION_RESERVED_KEYS.include?(pattern)
              raise ReservedInterpolationKey.new(pattern, string)
            elsif !values.include?(key)
              raise MissingInterpolationArgument.new(pattern, string)
            else
              values[key].to_s
            end
          end
        end

        # Loads a single translations file by delegating to #load_rb or
        # #load_yml depending on the file extension and directly merges the
        # data to the existing translations. Raises I18n::UnknownFileType
        # for all other file extensions.
        def load_file(filename)
          type = File.extname(filename).tr('.', '').downcase
          raise UnknownFileType.new(type, filename) unless respond_to?(:"load_#{type}")
          data = send :"load_#{type}", filename # TODO raise a meaningful exception if this does not yield a Hash
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
          require 'yaml' unless defined? :YAML
          YAML::load(IO.read(filename))
        end

        # Deep merges the given translations hash with the existing translations
        # for the given locale
        def merge_translations(locale, data)
          locale = locale.to_sym
          translations[locale] ||= {}
          data = deep_symbolize_keys(data)

          # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
          merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
          translations[locale].merge!(data, &merger)
        end

        # Return a new hash with all keys and nested keys converted to symbols.
        def deep_symbolize_keys(hash)
          hash.inject({}) { |result, (key, value)|
            value = deep_symbolize_keys(value) if value.is_a? Hash
            result[(key.to_sym rescue key) || key] = value
            result
          }
        end
    end
  end
end
