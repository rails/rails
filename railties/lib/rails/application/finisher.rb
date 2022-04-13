# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/array/conversions"
require "active_support/descendants_tracker"
require "active_support/dependencies"

module Rails
  class Application
    module Finisher
      include Initializable

      initializer :add_generator_templates do
        config.generators.templates.unshift(*paths["lib/templates"].existent)
      end

      initializer :setup_main_autoloader do
        autoloader = Rails.autoloaders.main

        ActiveSupport::Dependencies.autoload_paths.freeze
        ActiveSupport::Dependencies.autoload_paths.uniq.each do |path|
          # Zeitwerk only accepts existing directories in `push_dir`.
          next unless File.directory?(path)

          autoloader.push_dir(path)
          autoloader.do_not_eager_load(path) unless ActiveSupport::Dependencies.eager_load?(path)
        end

        unless config.cache_classes
          autoloader.enable_reloading
          ActiveSupport::Dependencies.autoloader = autoloader

          autoloader.on_load do |_cpath, value, _abspath|
            if value.is_a?(Class) && value.singleton_class < ActiveSupport::DescendantsTracker
              ActiveSupport::Dependencies._autoloaded_tracked_classes << value
            end
          end
        end

        autoloader.setup
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

      initializer :eager_load! do |app|
        if config.eager_load
          ActiveSupport.run_load_hooks(:before_eager_load, self)
          Zeitwerk::Loader.eager_load_all
          config.eager_load_namespaces.each(&:eager_load!)

          unless config.cache_classes
            app.reloader.after_class_unload do
              Rails.autoloaders.main.eager_load
            end
          end
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

      initializer :add_internal_routes do |app|
        if Rails.env.development?
          app.routes.prepend do
            get "/rails/info/properties" => "rails/info#properties", internal: true
            get "/rails/info/routes"     => "rails/info#routes",     internal: true
            get "/rails/info"            => "rails/info#index",      internal: true
          end

          routes_reloader.run_after_load_paths = -> do
            app.routes.append do
              get "/" => "rails/welcome#index", internal: true
            end
          end
        end
      end

      # Set routes reload after the finisher hook to ensure routes added in
      # the hook are taken into account.
      initializer :set_routes_reloader_hook do |app|
        reloader = routes_reloader
        reloader.eager_load = app.config.eager_load
        reloader.execute
        reloaders << reloader
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
          reloader.execute
        end
      end

      # Set clearing dependencies after the finisher hook to ensure paths
      # added in the hook are taken into account.
      initializer :set_clear_dependencies_hook, group: :all do |app|
        callback = lambda do
          # Order matters.
          ActiveSupport::DescendantsTracker.clear(ActiveSupport::Dependencies._autoloaded_tracked_classes)
          ActiveSupport::Dependencies.clear
        end

        if config.cache_classes
          app.reloader.check = lambda { false }
        elsif config.reload_classes_only_on_change
          app.reloader.check = lambda do
            app.reloaders.map(&:updated?).any?
          end
        else
          app.reloader.check = lambda { true }
        end

        if config.cache_classes
          # No reloader
          ActiveSupport::DescendantsTracker.disable_clear!
        elsif config.reload_classes_only_on_change
          reloader = config.file_watcher.new(*watchable_args, &callback)
          reloaders << reloader

          # Prepend this callback to have autoloaded constants cleared before
          # any other possible reloading, in case they need to autoload fresh
          # constants.
          app.reloader.to_run(prepend: true) do
            # In addition to changes detected by the file watcher, if routes
            # or i18n have been updated we also need to clear constants,
            # that's why we run #execute rather than #execute_if_updated, this
            # callback has to clear autoloaded constants after any update.
            class_unload! do
              reloader.execute
            end
          end
        else
          app.reloader.to_complete do
            class_unload!(&callback)
          end
        end
      end
    end
  end
end
