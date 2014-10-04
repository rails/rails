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

      initializer :add_builtin_route do |app|
        if Rails.env.development?
          app.routes.append do
            get '/rails/info/properties' => "rails/info#properties"
            get '/rails/info/routes'     => "rails/info#routes"
            get '/rails/info'            => "rails/info#index"
            get '/'                      => "rails/welcome#index"
          end
        end
      end

      initializer :build_middleware_stack do
        build_middleware_stack
      end

      initializer :define_main_app_helper do |app|
        app.routes.define_mounted_helper(:main_app)
      end

      initializer :add_to_prepare_blocks do
        config.to_prepare_blocks.each do |block|
          ActionDispatch::Reloader.to_prepare(&block)
        end
      end

      # This needs to happen before eager load so it happens
      # in exactly the same point regardless of config.cache_classes
      initializer :run_prepare_callbacks do
        ActionDispatch::Reloader.prepare!
      end

      initializer :eager_load! do
        if config.eager_load
          ActiveSupport.run_load_hooks(:before_eager_load, self)
          config.eager_load_namespaces.each(&:eager_load!)
        end
      end

      # All initialization is done, including eager loading in production
      initializer :finisher_hook do
        ActiveSupport.run_load_hooks(:after_initialize, self)
      end

      # Set routes reload after the finisher hook to ensure routes added in
      # the hook are taken into account.
      initializer :set_routes_reloader_hook do
        reloader = routes_reloader
        reloader.execute_if_updated
        self.reloaders << reloader
        ActionDispatch::Reloader.to_prepare do
          # We configure #execute rather than #execute_if_updated because if
          # autoloaded constants are cleared we need to reload routes also in
          # case any was used there, as in
          #
          #   mount MailPreview => 'mail_view'
          #
          # This means routes are also reloaded if i18n is updated, which
          # might not be necessary, but in order to be more precise we need
          # some sort of reloaders dependency support, to be added.
          reloader.execute
        end
      end

      # Set clearing dependencies after the finisher hook to ensure paths
      # added in the hook are taken into account.
      initializer :set_clear_dependencies_hook, group: :all do
        callback = lambda do
          ActiveSupport::DescendantsTracker.clear
          ActiveSupport::Dependencies.clear
        end

        if config.reload_classes_only_on_change
          reloader = config.file_watcher.new(*watchable_args, &callback)
          self.reloaders << reloader

          # Prepend this callback to have autoloaded constants cleared before
          # any other possible reloading, in case they need to autoload fresh
          # constants.
          ActionDispatch::Reloader.to_prepare(prepend: true) do
            # In addition to changes detected by the file watcher, if routes
            # or i18n have been updated we also need to clear constants,
            # that's why we run #execute rather than #execute_if_updated, this
            # callback has to clear autoloaded constants after any update.
            reloader.execute
          end
        else
          ActionDispatch::Reloader.to_cleanup(&callback)
        end
      end
    end
  end
end
