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
  autoload :Helpers, 'i18n/helpers'
  autoload :Locale,  'i18n/locale'

  @@backend = nil
  @@load_path = nil
  @@default_locale = :en
  @@default_separator = '.'
  @@exception_handler = :default_exception_handler

  class << self
    # Returns the current backend. Defaults to +Backend::Simple+.
    def backend
      @@backend ||= Backend::Simple.new
    end

    # Sets the current backend. Used to set a custom backend.
    def backend=(backend)
      @@backend = backend
    end

    # Returns the current default locale. Defaults to :'en'
    def default_locale
      @@default_locale
    end

    # Sets the current default locale. Used to set a custom default locale.
    def default_locale=(locale)
      @@default_locale = locale.to_sym rescue nil
    end

    # Returns the current locale. Defaults to I18n.default_locale.
    def locale
      Thread.current[:locale] ||= default_locale
    end

    # Sets the current locale pseudo-globally, i.e. in the Thread.current hash.
    def locale=(locale)
      Thread.current[:locale] = locale.to_sym rescue nil
    end

    # Returns an array of locales for which translations are available.
    # Unless you explicitely set the these through I18n.available_locales=
    # the call will be delegated to the backend and memoized on the I18n module.
    def available_locales
      @@available_locales ||= backend.available_locales
    end

    # Sets the available locales.
    def available_locales=(locales)
      @@available_locales = locales
    end

    # Returns the current default scope separator. Defaults to '.'
    def default_separator
      @@default_separator
    end

    # Sets the current default scope separator.
    def default_separator=(separator)
      @@default_separator = separator
    end

    # Sets the exception handler.
    def exception_handler=(exception_handler)
      @@exception_handler = exception_handler
    end

    # Allow clients to register paths providing translation data sources. The
    # backend defines acceptable sources.
    #
    # E.g. the provided SimpleBackend accepts a list of paths to translation
    # files which are either named *.rb and contain plain Ruby Hashes or are
    # named *.yml and contain YAML data. So for the SimpleBackend clients may
    # register translation files like this:
    #   I18n.load_path << 'path/to/locale/en.yml'
    def load_path
      @@load_path ||= []
    end

    # Sets the load path instance. Custom implementations are expected to
    # behave like a Ruby Array.
    def load_path=(load_path)
      @@load_path = load_path
    end

    # Tells the backend to reload translations. Used in situations like the
    # Rails development environment. Backends can implement whatever strategy
    # is useful.
    def reload!
      backend.reload!
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
    # <em>E.g.</em>, with a translation <tt>:foo => "foo {{bar}}"</tt> the option
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
    # <tt>:foo => ['{{count}} foo', '{{count}} foos']</tt>, count will
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
    #   lambda { |key, options| options[:gender] == 'm' ? "Mr. {{options[:name]}}" : "Mrs. {{options[:name]}}" }
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
      locale  = options && options.delete(:locale) || I18n.locale
      raises  = options && options.delete(:raise)
      backend.translate(locale, key, options || {})
    rescue I18n::ArgumentError => exception
      raise exception if raises
      handle_exception(exception, locale, key, options)
    end
    alias :t :translate

    def translate!(key, options = {})
      translate(key, options.merge( :raise => true ))
    end
    alias :t! :translate!

    # Localizes certain objects, such as dates and numbers to local formatting.
    def localize(object, options = {})
      locale = options[:locale] || I18n.locale
      format = options[:format] || :default
      backend.localize(locale, object, format)
    end
    alias :l :localize

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
      case @@exception_handler
      when Symbol
        send(@@exception_handler, exception, locale, key, options)
      else
        @@exception_handler.call(exception, locale, key, options)
      end
    end

    # Merges the given locale, key and scope into a single array of keys.
    # Splits keys that contain dots into multiple keys. Makes sure all
    # keys are Symbols.
    def normalize_translation_keys(locale, key, scope, separator = nil)
      keys = [locale] + Array(scope) + Array(key)
      keys = keys.map { |k| k.to_s.split(separator || I18n.default_separator) }
      keys = keys.flatten - ['']
      keys.map { |k| k.to_sym }
    end
  end
end
