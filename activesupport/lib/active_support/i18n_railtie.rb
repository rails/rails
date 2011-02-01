require "active_support"
require "rails"
require "active_support/file_update_checker"
require "active_support/core_ext/array/wrap"

module I18n
  class Railtie < Rails::Railtie
    config.i18n = ActiveSupport::OrderedOptions.new
    config.i18n.railties_load_path = []
    config.i18n.load_path = []
    config.i18n.fallbacks = ActiveSupport::OrderedOptions.new

    def self.reloader
      @reloader ||= ActiveSupport::FileUpdateChecker.new([]){ I18n.reload! }
    end

    # Add I18n::Railtie.reloader to ActionDispatch callbacks. Since, at this
    # point, no path was added to the reloader, I18n.reload! is not triggered
    # on to_prepare callbacks. This will only happen on the config.after_initialize
    # callback below.
    initializer "i18n.callbacks" do
      ActionDispatch::Callbacks.to_prepare do
        I18n::Railtie.reloader.execute_if_updated
      end
    end

    # Set the i18n configuration after initialization since a lot of
    # configuration is still usually done in application initializers.
    config.after_initialize do |app|
      I18n::Railtie.initialize_i18n(app)
    end

    # Trigger i18n config before any eager loading has happened
    # so it's ready if any classes require it when eager loaded
    config.before_eager_load do |app|
      I18n::Railtie.initialize_i18n(app)
    end

  protected

    # Setup i18n configuration
    def self.initialize_i18n(app)
      return if @i18n_inited

      fallbacks = app.config.i18n.delete(:fallbacks)

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

      reloader.paths.concat I18n.load_path
      reloader.execute_if_updated

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
