# encoding: utf-8

# Authors::   Sven Fuchs (http://www.artweb-design.de),
#             Joshua Harvey (http://www.workingwithrails.com/person/759-joshua-harvey),
#             Stephan Soller (http://www.arkanis-development.de/),
#             Saimon Moore (http://saimonmoore.net),
#             Matt Aimonetti (http://railsontherun.com/)
# Copyright:: Copyright (c) 2008 The Ruby i18n Team
# License::   MIT
require 'i18n/exceptions'
require 'i18n/core_ext/string/interpolate'

module I18n
  autoload :Backend, 'i18n/backend'
  autoload :Config,  'i18n/config'
  autoload :Gettext, 'i18n/gettext'
  autoload :Locale,  'i18n/locale'

  class << self
    # Gets I18n configuration object.
    def config
      Thread.current[:i18n_config] ||= I18n::Config.new
    end

    # Sets I18n configuration object.
    def config=(value)
      Thread.current[:i18n_config] = value
    end

    # Write methods which delegates to the configuration object
    %w(locale backend default_locale available_locales default_separator
      exception_handler load_path).each do |method|
      module_eval <<-DELEGATORS, __FILE__, __LINE__ + 1
        def #{method}
          config.#{method}
        end

        def #{method}=(value)
          config.#{method} = (value)
        end
      DELEGATORS
    end

    # Tells the backend to reload translations. Used in situations like the
    # Rails development environment. Backends can implement whatever strategy
    # is useful.
    def reload!
      config.backend.reload!
    end

    # Translates, pluralizes and interpolates a given key using a given locale,
    # scope, and default, as well as interpolation values.
    #
    # *LOOKUP*
    #
    # Translation data is organized as a nested hash using the upper-level keys
    # as namespaces. <em>E.g.</em>, ActionView ships with the translation:
    # <tt>:date => {:formats => {:short => "%b %d"}}</tt>.
    #
    # Translations can be looked up at any level of this hash using the key argument
    # and the scope option. <em>E.g.</em>, in this example <tt>I18n.t :date</tt>
    # returns the whole translations hash <tt>{:formats => {:short => "%b %d"}}</tt>.
    #
    # Key can be either a single key or a dot-separated key (both Strings and Symbols
    # work). <em>E.g.</em>, the short format can be looked up using both:
    #   I18n.t 'date.formats.short'
    #   I18n.t :'date.formats.short'
    #
    # Scope can be either a single key, a dot-separated key or an array of keys
    # or dot-separated keys. Keys and scopes can be combined freely. So these
    # examples will all look up the same short date format:
    #   I18n.t 'date.formats.short'
    #   I18n.t 'formats.short', :scope => 'date'
    #   I18n.t 'short', :scope => 'date.formats'
    #   I18n.t 'short', :scope => %w(date formats)
    #
    # *INTERPOLATION*
    #
    # Translations can contain interpolation variables which will be replaced by
    # values passed to #translate as part of the options hash, with the keys matching
    # the interpolation variable names.
    #
    # <em>E.g.</em>, with a translation <tt>:foo => "foo %{bar}"</tt> the option
    # value for the key +bar+ will be interpolated into the translation:
    #   I18n.t :foo, :bar => 'baz' # => 'foo baz'
    #
    # *PLURALIZATION*
    #
    # Translation data can contain pluralized translations. Pluralized translations
    # are arrays of singluar/plural versions of translations like <tt>['Foo', 'Foos']</tt>.
    #
    # Note that <tt>I18n::Backend::Simple</tt> only supports an algorithm for English
    # pluralization rules. Other algorithms can be supported by custom backends.
    #
    # This returns the singular version of a pluralized translation:
    #   I18n.t :foo, :count => 1 # => 'Foo'
    #
    # These both return the plural version of a pluralized translation:
    #   I18n.t :foo, :count => 0 # => 'Foos'
    #   I18n.t :foo, :count => 2 # => 'Foos'
    #
    # The <tt>:count</tt> option can be used both for pluralization and interpolation.
    # <em>E.g.</em>, with the translation
    # <tt>:foo => ['%{count} foo', '%{count} foos']</tt>, count will
    # be interpolated to the pluralized translation:
    #   I18n.t :foo, :count => 1 # => '1 foo'
    #
    # *DEFAULTS*
    #
    # This returns the translation for <tt>:foo</tt> or <tt>default</tt> if no translation was found:
    #   I18n.t :foo, :default => 'default'
    #
    # This returns the translation for <tt>:foo</tt> or the translation for <tt>:bar</tt> if no
    # translation for <tt>:foo</tt> was found:
    #   I18n.t :foo, :default => :bar
    #
    # Returns the translation for <tt>:foo</tt> or the translation for <tt>:bar</tt>
    # or <tt>default</tt> if no translations for <tt>:foo</tt> and <tt>:bar</tt> were found.
    #   I18n.t :foo, :default => [:bar, 'default']
    #
    # *BULK LOOKUP*
    #
    # This returns an array with the translations for <tt>:foo</tt> and <tt>:bar</tt>.
    #   I18n.t [:foo, :bar]
    #
    # Can be used with dot-separated nested keys:
    #   I18n.t [:'baz.foo', :'baz.bar']
    #
    # Which is the same as using a scope option:
    #   I18n.t [:foo, :bar], :scope => :baz
    #
    # *LAMBDAS*
    #
    # Both translations and defaults can be given as Ruby lambdas. Lambdas will be
    # called and passed the key and options.
    #
    # E.g. assuming the key <tt>:salutation</tt> resolves to:
    #   lambda { |key, options| options[:gender] == 'm' ? "Mr. %{options[:name]}" : "Mrs. %{options[:name]}" }
    #
    # Then <tt>I18n.t(:salutation, :gender => 'w', :name => 'Smith') will result in "Mrs. Smith".
    #
    # It is recommended to use/implement lambdas in an "idempotent" way. E.g. when
    # a cache layer is put in front of I18n.translate it will generate a cache key
    # from the argument values passed to #translate. Therefor your lambdas should
    # always return the same translations/values per unique combination of argument
    # values.
    def translate(*args)
      options = args.pop if args.last.is_a?(Hash)
      key     = args.shift
      locale  = options && options.delete(:locale) || config.locale
      raises  = options && options.delete(:raise)
      config.backend.translate(locale, key, options || {})
    rescue I18n::ArgumentError => exception
      raise exception if raises
      handle_exception(exception, locale, key, options)
    end
    alias :t :translate

    def translate!(key, options = {})
      translate(key, options.merge( :raise => true ))
    end
    alias :t! :translate!

    # Transliterates UTF-8 characters to ASCII. By default this method will
    # transliterate only Latin strings to an ASCII approximation:
    #
    #    I18n.transliterate("Ærøskøbing")
    #    # => "AEroskobing"
    #
    #    I18n.transliterate("日本語")
    #    # => "???"
    #
    # It's also possible to add support for per-locale transliterations. I18n
    # expects transliteration rules to be stored at
    # <tt>i18n.transliterate.rule</tt>.
    #
    # Transliteration rules can either be a Hash or a Proc. Procs must accept a
    # single string argument. Hash rules inherit the default transliteration
    # rules, while Procs do not.
    #
    # *Examples*
    #
    # Setting a Hash in <locale>.yml:
    #
    #    i18n:
    #      transliterate:
    #        rule:
    #          ü: "ue"
    #          ö: "oe"
    #
    # Setting a Hash using Ruby:
    #
    #     store_translations(:de, :i18n => {
    #       :transliterate => {
    #         :rule => {
    #           "ü" => "ue",
    #           "ö" => "oe"
    #         }
    #       }
    #     )
    #
    # Setting a Proc:
    #
    #     translit = lambda {|string| MyTransliterator.transliterate(string) }
    #     store_translations(:xx, :i18n => {:transliterate => {:rule => translit})
    #
    # Transliterating strings:
    #
    #     I18n.locale = :en
    #     I18n.transliterate("Jürgen") # => "Jurgen"
    #     I18n.locale = :de
    #     I18n.transliterate("Jürgen") # => "Juergen"
    #     I18n.transliterate("Jürgen", :locale => :en) # => "Jurgen"
    #     I18n.transliterate("Jürgen", :locale => :de) # => "Juergen"
    def transliterate(*args)
      options      = args.pop if args.last.is_a?(Hash)
      key          = args.shift
      locale       = options && options.delete(:locale) || config.locale
      raises       = options && options.delete(:raise)
      replacement  = options && options.delete(:replacement)
      config.backend.transliterate(locale, key, replacement)
    rescue I18n::ArgumentError => exception
      raise exception if raises
      handle_exception(exception, locale, key, options)
    end

    # Localizes certain objects, such as dates and numbers to local formatting.
    def localize(object, options = {})
      locale = options.delete(:locale) || config.locale
      format = options.delete(:format) || :default
      config.backend.localize(locale, object, format, options)
    end
    alias :l :localize

    # Executes block with given I18n.locale set.
    def with_locale(tmp_locale = nil)
      if tmp_locale
        current_locale = self.locale
        self.locale    = tmp_locale
      end
      yield
    ensure
      self.locale = current_locale if tmp_locale
    end


    # Merges the given locale, key and scope into a single array of keys.
    # Splits keys that contain dots into multiple keys. Makes sure all
    # keys are Symbols.
    def normalize_keys(locale, key, scope, separator = nil)
      separator ||= I18n.default_separator

      keys = []
      keys.concat normalize_key(locale, separator)
      keys.concat normalize_key(scope, separator)
      keys.concat normalize_key(key, separator)
      keys
    end

  # making these private until Ruby 1.9.2 can send to protected methods again
  # see http://redmine.ruby-lang.org/repositories/revision/ruby-19?rev=24280
  private

    # Handles exceptions raised in the backend. All exceptions except for
    # MissingTranslationData exceptions are re-raised. When a MissingTranslationData
    # was caught and the option :raise is not set the handler returns an error
    # message string containing the key/scope.
    def default_exception_handler(exception, locale, key, options)
      return exception.message if MissingTranslationData === exception
      raise exception
    end

    # Any exceptions thrown in translate will be sent to the @@exception_handler
    # which can be a Symbol, a Proc or any other Object.
    #
    # If exception_handler is a Symbol then it will simply be sent to I18n as
    # a method call. A Proc will simply be called. In any other case the
    # method #call will be called on the exception_handler object.
    #
    # Examples:
    #
    #   I18n.exception_handler = :default_exception_handler             # this is the default
    #   I18n.default_exception_handler(exception, locale, key, options) # will be called like this
    #
    #   I18n.exception_handler = lambda { |*args| ... }                 # a lambda
    #   I18n.exception_handler.call(exception, locale, key, options)    # will be called like this
    #
    #  I18n.exception_handler = I18nExceptionHandler.new                # an object
    #  I18n.exception_handler.call(exception, locale, key, options)     # will be called like this
    def handle_exception(exception, locale, key, options)
      case config.exception_handler
      when Symbol
        send(config.exception_handler, exception, locale, key, options)
      else
        config.exception_handler.call(exception, locale, key, options)
      end
    end

    # Deprecated. Will raise a warning in future versions and then finally be
    # removed. Use I18n.normalize_keys instead.
    def normalize_translation_keys(locale, key, scope, separator = nil)
      normalize_keys(locale, key, scope, separator)
    end

    def normalize_key(key, separator)
      normalized_key_cache[separator][key] ||=
        case key
        when Array
          key.map { |k| normalize_key(k, separator) }.flatten
        else
          keys = key.to_s.split(separator)
          keys.delete('')
          keys.map!{ |k| k.to_sym }
          keys
        end
    end

    def normalized_key_cache
      @normalized_key_cache ||= Hash.new { |h,k| h[k] = {} }
    end
  end
end
