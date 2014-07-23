require "active_support"
require "active_support/file_update_checker"
require "active_support/core_ext/array/wrap"

module I18n
  class Railtie < Rails::Railtie
    config.i18n = ActiveSupport::OrderedOptions.new
    config.i18n.railties_load_path = []
    config.i18n.load_path = []
    config.i18n.fallbacks = ActiveSupport::OrderedOptions.new

    # Set the i18n configuration after initialization since a lot of
    # configuration is still usually done in application initializers.
    config.after_initialize do |app|
      I18n::Railtie.initialize_i18n(app)
    end

    # Trigger i18n config before any eager loading has happened
    # so it's ready if any classes require it when eager loaded.
    config.before_eager_load do |app|
      I18n::Railtie.initialize_i18n(app)
    end

  protected

    @i18n_inited = false

    # Setup i18n configuration.
    def self.initialize_i18n(app)
      return if @i18n_inited

      fallbacks = app.config.i18n.delete(:fallbacks)

      # Avoid issues with setting the default_locale by disabling available locales
      # check while configuring.
      enforce_available_locales = app.config.i18n.delete(:enforce_available_locales)
      enforce_available_locales = I18n.enforce_available_locales if enforce_available_locales.nil?
      I18n.enforce_available_locales = false

      app.config.i18n.each do |setting, value|
        case setting
        when :railties_load_path
          app.config.i18n.load_path.unshift(*value)
        when :load_path
          I18n.load_path += value
        else
          I18n.send("#{setting}=", value)
        end
      end

      init_fallbacks(fallbacks) if fallbacks && validate_fallbacks(fallbacks)

      # Restore available locales check so it will take place from now on.
      I18n.enforce_available_locales = enforce_available_locales

      reloader = ActiveSupport::FileUpdateChecker.new(I18n.load_path.dup){ I18n.reload! }
      app.reloaders << reloader
      ActionDispatch::Reloader.to_prepare { reloader.execute_if_updated }
      reloader.execute

      @i18n_inited = true
    end

    def self.include_fallbacks_module
      I18n.backend.class.send(:include, I18n::Backend::Fallbacks)
    end

    def self.init_fallbacks(fallbacks)
      include_fallbacks_module

      args = case fallbacks
      when ActiveSupport::OrderedOptions
        [*(fallbacks[:defaults] || []) << fallbacks[:map]].compact
      when Hash, Array
        Array.wrap(fallbacks)
      else # TrueClass
        []
      end

      I18n.fallbacks = I18n::Locale::Fallbacks.new(*args)
    end

    def self.validate_fallbacks(fallbacks)
      case fallbacks
      when ActiveSupport::OrderedOptions
        !fallbacks.empty?
      when TrueClass, Array, Hash
        true
      else
        raise "Unexpected fallback type #{fallbacks.inspect}"
      end
    end
  end
end
