# encoding: utf-8

class KeyError < IndexError
  def initialize(message = nil)
    super(message || "key not found")
  end
end unless defined?(KeyError)

module I18n
  class ArgumentError < ::ArgumentError; end

  class InvalidLocale < ArgumentError
    attr_reader :locale
    def initialize(locale)
      @locale = locale
      super "#{locale.inspect} is not a valid locale"
    end
  end

  class MissingTranslationData < ArgumentError
    attr_reader :locale, :key, :options
    def initialize(locale, key, opts = nil)
      @key, @locale, @options = key, locale, opts || {}
      keys = I18n.send(:normalize_translation_keys, locale, key, options[:scope])
      keys << 'no key' if keys.size < 2
      super "translation missing: #{keys.join(', ')}"
    end
  end

  class InvalidPluralizationData < ArgumentError
    attr_reader :entry, :count
    def initialize(entry, count)
      @entry, @count = entry, count
      super "translation data #{entry.inspect} can not be used with :count => #{count}"
    end
  end

  class MissingInterpolationArgument < ArgumentError
    attr_reader :values, :string
    def initialize(values, string)
      @values, @string = values, string
      super "missing interpolation argument in #{string.inspect} (#{values.inspect} given)"
    end
  end

  class ReservedInterpolationKey < ArgumentError
    attr_reader :key, :string
    def initialize(key, string)
      @key, @string = key, string
      super "reserved key #{key.inspect} used in #{string.inspect}"
    end
  end

  class UnknownFileType < ArgumentError
    attr_reader :type, :filename
    def initialize(type, filename)
      @type, @filename = type, filename
      super "can not load translations from #{filename}, the file type #{type} is not known"
    end
  end
end