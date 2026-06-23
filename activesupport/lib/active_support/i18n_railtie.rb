# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/array/wrap"
require "rails/railtie"

# :enddoc:

module I18n
  class Railtie < Rails::Railtie
    config.i18n = ActiveSupport::OrderedOptions.new
    config.i18n.railties_load_path = []
    config.i18n.load_path = []
    config.i18n.fallbacks = ActiveSupport::OrderedOptions.new

    config.eager_load_namespaces << I18n

    # Make sure i18n is ready before eager loading, in case any eager loaded
    # code needs it.
    config.before_eager_load do |app|
      I18n::Railtie.initialize_i18n(app)
    end

    # i18n initialization needs to run after application initialization, since
    # initializers may configure i18n.
    #
    # If the application eager loaded, this was done on before_eager_load. The
    # hook is still OK, though, because initialize_i18n is idempotent.
    config.after_initialize do |app|
      I18n::Railtie.initialize_i18n(app)
    end

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

      reloadable_paths = []
      app.config.i18n.each do |setting, value|
        case setting
        when :railties_load_path
          reloadable_paths = value
          app.config.i18n.load_path.unshift(*value.flat_map(&:existent))
        when :load_path
          I18n.load_path += value
        when :raise_on_missing_translations
          strict = value == :strict
          setup_raise_on_missing_translations_config(app, strict)
        else
          I18n.public_send("#{setting}=", value)
        end
      end

      init_fallbacks(fallbacks) if fallbacks && validate_fallbacks(fallbacks)

      # Restore available locales check so it will take place from now on.
      I18n.enforce_available_locales = enforce_available_locales

      if app.config.reloading_enabled?
        directories = watched_dirs_with_extensions(reloadable_paths)
        reloader = app.config.file_watcher.new(I18n.load_path, directories) do
          I18n.load_path.delete_if { |path| path.to_s.start_with?(Rails.root.to_s) && !File.exist?(path) }
          I18n.load_path |= reloadable_paths.flat_map(&:existent)
        end

        app.reloaders << reloader
        app.reloader.to_run do
          reloader.execute_if_updated { require_unload_lock! }
        end
      end

      @i18n_inited = true
    end

    def self.setup_raise_on_missing_translations_config(app, strict)
      ActiveSupport.on_load(:action_view) do
        ActionView::Helpers::TranslationHelper.raise_on_missing_translations = app.config.i18n.raise_on_missing_translations
      end

      ActiveSupport.on_load(:active_model_translation) do
        ActiveModel::Translation.raise_on_missing_translations = app.config.i18n.raise_on_missing_translations if strict
      end

      if app.config.i18n.raise_on_missing_translations &&
          I18n.exception_handler.is_a?(I18n::ExceptionHandler) # Only override the i18n gem's default exception handler.

        I18n.exception_handler = ->(exception, *) {
          exception = exception.to_exception if exception.is_a?(I18n::MissingTranslation)
          raise exception
        }
      end
    end

    def self.include_fallbacks_module
      I18n.backend.class.include(I18n::Backend::Fallbacks)
    end

    def self.init_fallbacks(fallbacks)
      include_fallbacks_module

      args = \
        case fallbacks
        when ActiveSupport::OrderedOptions
          [*(fallbacks[:defaults] || []) << fallbacks[:map]].compact
        when Hash, Array
          Array.wrap(fallbacks)
        else # TrueClass
          [I18n.default_locale]
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

    def self.watched_dirs_with_extensions(paths)
      paths.each_with_object({}) do |path, result|
        result[path.absolute_current] = path.extensions
      end
    end
  end
end
