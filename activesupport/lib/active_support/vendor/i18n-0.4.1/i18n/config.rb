module I18n
  class Config
    # The only configuration value that is not global and scoped to thread is :locale.
    # It defaults to the default_locale.
    def locale
      @locale ||= default_locale
    end

    # Sets the current locale pseudo-globally, i.e. in the Thread.current hash.
    def locale=(locale)
      @locale = locale.to_sym rescue nil
    end

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
      @@default_locale ||= :en
    end

    # Sets the current default locale. Used to set a custom default locale.
    def default_locale=(locale)
      @@default_locale = locale.to_sym rescue nil
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
      @@default_separator ||= '.'
    end

    # Sets the current default scope separator.
    def default_separator=(separator)
      @@default_separator = separator
    end

    # Return the current exception handler. Defaults to :default_exception_handler.
    def exception_handler
      @@exception_handler ||= :default_exception_handler
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
  end
end