# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/array/conversions"

module Rails
  class Application
    module Finisher
      include Initializable

      initializer :add_generator_templates do
        config.generators.templates.unshift(*paths["lib/templates"].existent)
      end

      initializer :ensure_autoload_once_paths_as_subset do
        extra = ActiveSupport::Dependencies.autoload_once_paths -
                ActiveSupport::Dependencies.autoload_paths

        unless extra.empty?
          abort <<-end_error
            autoload_once_paths must be a subset of the autoload_paths.
            Extra items in autoload_once_paths: #{extra * ','}
          end_error
        end
      end

      # This will become an error if/when we remove classic mode. The plan is
      # autoloaders won't be configured up to this point in the finisher, so
      # constants just won't be found, raising regular NameError exceptions.
      initializer :warn_if_autoloaded, before: :let_zeitwerk_take_over do
        next if config.cache_classes
        next if ActiveSupport::Dependencies.autoloaded_constants.empty?

        autoloaded    = ActiveSupport::Dependencies.autoloaded_constants
        constants     = "constant".pluralize(autoloaded.size)
        enum          = autoloaded.to_sentence
        have          = autoloaded.size == 1 ? "has" : "have"
        these         = autoloaded.size == 1 ? "This" : "These"
        example       = autoloaded.first
        example_klass = example.constantize.class

        if config.autoloader == :zeitwerk
          ActiveSupport::DescendantsTracker.clear
          ActiveSupport::Dependencies.clear

          unload_message = "#{these} autoloaded #{constants} #{have} been unloaded."
        else
          unload_message = "`config.autoloader` is set to `#{config.autoloader}`. #{these} autoloaded #{constants} would have been unloaded if `config.autoloader` had been set to `:zeitwerk`."
        end

        ActiveSupport::Deprecation.warn(<<~WARNING)
          Initialization autoloaded the #{constants} #{enum}.

          Being able to do this is deprecated. Autoloading during initialization is going
          to be an error condition in future versions of Rails.

          Reloading does not reboot the application, and therefore code executed during
          initialization does not run again. So, if you reload #{example}, for example,
          the expected changes won't be reflected in that stale #{example_klass} object.

          #{unload_message}

          In order to autoload safely at boot time, please wrap your code in a reloader
          callback this way:

              Rails.application.reloader.to_prepare do
                # Autoload classes and modules needed at boot time here.
              end

          That block runs when the application boots, and every time there is a reload.
          For historical reasons, it may run twice, so it has to be idempotent.

          Check the "Autoloading and Reloading Constants" guide to learn more about how
          Rails autoloads and reloads.
        WARNING
      end

      initializer :let_zeitwerk_take_over do
        if config.autoloader == :zeitwerk
          require "active_support/dependencies/zeitwerk_integration"
          ActiveSupport::Dependencies::ZeitwerkIntegration.take_over(enable_reloading: !config.cache_classes)
        end
      end

      initializer :add_builtin_route do |app|
        if Rails.env.development?
          app.routes.prepend do
            get "/rails/info/properties" => "rails/info#properties", internal: true
            get "/rails/info/routes"     => "rails/info#routes", internal: true
            get "/rails/info"            => "rails/info#index", internal: true
          end

          app.routes.append do
            get "/"                      => "rails/welcome#index", internal: true
          end
        end
      end

      # Setup default session store if not already set in config/application.rb
      initializer :setup_default_session_store, before: :build_middleware_stack do |app|
        unless app.config.session_store?
          app_name = app.class.name ? app.railtie_name.chomp("_application") : ""
          app.config.session_store :cookie_store, key: "_#{app_name}_session"
        end
      end

      initializer :build_middleware_stack do
        build_middleware_stack
      end

      initializer :define_main_app_helper do |app|
        app.routes.define_mounted_helper(:main_app)
      end

      initializer :add_to_prepare_blocks do |app|
        config.to_prepare_blocks.each do |block|
          app.reloader.to_prepare(&block)
        end
      end

      # This needs to happen before eager load so it happens
      # in exactly the same point regardless of config.eager_load
      initializer :run_prepare_callbacks do |app|
        app.reloader.prepare!
      end

      initializer :eager_load! do
        if config.eager_load
          ActiveSupport.run_load_hooks(:before_eager_load, self)
          # Checks defined?(Zeitwerk) instead of zeitwerk_enabled? because we
          # want to eager load any dependency managed by Zeitwerk regardless of
          # the autoloading mode of the application.
          Zeitwerk::Loader.eager_load_all if defined?(Zeitwerk)
          config.eager_load_namespaces.each(&:eager_load!)
        end
      end

      # All initialization is done, including eager loading in production
      initializer :finisher_hook do
        ActiveSupport.run_load_hooks(:after_initialize, self)
      end

      class MutexHook
        def initialize(mutex = Mutex.new)
          @mutex = mutex
        end

        def run
          @mutex.lock
        end

        def complete(_state)
          @mutex.unlock
        end
      end

      module InterlockHook
        def self.run
          ActiveSupport::Dependencies.interlock.start_running
        end

        def self.complete(_state)
          ActiveSupport::Dependencies.interlock.done_running
        end
      end

      initializer :configure_executor_for_concurrency do |app|
        if config.allow_concurrency == false
          # User has explicitly opted out of concurrent request
          # handling: presumably their code is not threadsafe

          app.executor.register_hook(MutexHook.new, outer: true)

        elsif config.allow_concurrency == :unsafe
          # Do nothing, even if we know this is dangerous. This is the
          # historical behavior for true.

        else
          # Default concurrency setting: enabled, but safe

          unless config.cache_classes && config.eager_load
            # Without cache_classes + eager_load, the load interlock
            # is required for proper operation

            app.executor.register_hook(InterlockHook, outer: true)
          end
        end
      end

      # Set routes reload after the finisher hook to ensure routes added in
      # the hook are taken into account.
      initializer :set_routes_reloader_hook do |app|
        routes_reloader.eager_load = app.config.eager_load
        routes_reloader.reload!
        app.reloader.register(:routes) { routes_reloader }

        app.reloader.to_run do
          # We configure #execute rather than #execute_if_updated because if
          # autoloaded constants are cleared we need to reload routes also in
          # case any was used there, as in
          #
          #   mount MailPreview => 'mail_view'
          #
          # This means routes are also reloaded if i18n is updated, which
          # might not be necessary, but in order to be more precise we need
          # some sort of reloaders dependency support, to be added.
          require_unload_lock!
          app.reloader.fetch(:routes).execute
        end
      end

      # Set clearing dependencies after the finisher hook to ensure paths
      # added in the hook are taken into account.
      initializer :set_clear_dependencies_hook, group: :all do |app|
        callback = lambda do
          ActiveSupport::DescendantsTracker.clear
          ActiveSupport::Dependencies.clear
        end

        if config.cache_classes
          # No reloader
          app.reloader.check = lambda { false }
        elsif config.reload_classes_only_on_change
          app.reloader.register(:watchable) do
            app.config.file_watcher.new(*watchable_args, &callback)
          end

          app.reloader.check = lambda { app.reloader.should_reload? }
          app.reloader.check!

          # Prepend this callback to have autoloaded constants cleared before
          # any other possible reloading, in case they need to autoload fresh
          # constants.
          app.reloader.to_run(prepend: true) do
            # In addition to changes detected by the file watcher, if routes
            # or i18n have been updated we also need to clear constants,
            # that's why we run #execute rather than #execute_if_updated, this
            # callback has to clear autoloaded constants after any update.
            class_unload! do
              app.reloader.fetch(:watchable).execute
            end
          end
        else
          app.reloader.check = lambda { true }
          app.reloader.check!

          app.reloader.to_complete do
            class_unload!(&callback)
          end
        end
      end

      # Disable dependency loading during request cycle
      initializer :disable_dependency_loading do
        if config.eager_load && config.cache_classes && !config.enable_dependency_loading
          ActiveSupport::Dependencies.unhook!
        end
      end
    end
  end
end
