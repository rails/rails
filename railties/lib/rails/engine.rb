require 'rails/railtie'
require 'active_support/core_ext/module/delegation'
require 'pathname'

module Rails
  # Rails::Engine allows you to wrap a specific Rails application and share it accross
  # different applications. Since Rails 3.0, every Rails::Application is nothing
  # more than an Engine, allowing you to share it very easily.
  #
  # Any Rails::Engine is also a Rails::Railtie, so the same methods (like rake_tasks and
  # generators) and configuration available in the latter can also be used in the former.
  #
  # == Creating an Engine
  #
  # In Rails versions before to 3.0, your gems automatically behaved as Engine, however
  # this coupled Rails to Rubygems. Since Rails 3.0, if you want a gem to automatically
  # behave as Engine, you have to specify an Engine for it somewhere inside your plugin
  # lib folder (similar with how we spceify a Railtie):
  #
  #   # lib/my_engine.rb
  #   module MyEngine
  #     class Engine < Rails::Engine
  #     end
  #   end
  #
  # Then ensure that this file is loaded at the top of your config/application.rb (or in
  # your Gemfile) and it will automatically load models, controllers, helpers and metals
  # inside app, load routes at "config/routes.rb", load locales at "config/locales/*",
  # load tasks at "lib/tasks/*".
  #
  # == Configuration
  #
  # Besides the Railtie configuration which is shared across the application, in a
  # Rails::Engine you can access load_paths, eager_load_paths and load_once_paths,
  # which differently from a Railtie, are scoped to the current Engine.
  #
  # Example:
  #
  #   class MyEngine < Rails::Engine
  #     # Add a load path for this specific Engine
  #     config.load_paths << File.expand_path("../lib/some/path", __FILE__)
  #
  #     initializer "my_engine.add_middleware" do |app|
  #       app.middlewares.use MyEngine::Middleware
  #     end
  #   end
  # 
  # == Paths
  #
  # Since Rails 3.0, both your Application and Engines do not have hardcoded paths.
  # This means that you are not required to place your controllers at "app/controllers",
  # but in any place which you find convenient.
  #
  # For example, let's suppose you want to lay your controllers at lib/controllers, all
  # you need to do is:
  #
  #   class MyEngine < Rails::Engine
  #     paths.app.controllers = "lib/controllers"
  #   end
  #
  # You can also have your controllers being loaded from both "app/controllers" and
  # "lib/controllers":
  #
  #   class MyEngine < Rails::Engine
  #     paths.app.controllers << "lib/controllers"
  #   end
  #
  # The available paths in an Engine are:
  #
  #   class MyEngine < Rails::Engine
  #     paths.app                 = "app"
  #     paths.app.controllers     = "app/controllers"
  #     paths.app.helpers         = "app/helpers"
  #     paths.app.models          = "app/models"
  #     paths.app.metals          = "app/metal"
  #     paths.app.views           = "app/views"
  #     paths.lib                 = "lib"
  #     paths.lib.tasks           = "lib/tasks"
  #     paths.config              = "config"
  #     paths.config.initializers = "config/initializers"
  #     paths.config.locales      = "config/locales"
  #     paths.config.routes       = "config/routes.rb"
  #   end
  #
  # Your Application class adds a couple more paths to this set. And as in your Application,
  # all folders under "app" are automatically added to the load path. So if you have
  # "app/observers", it's added by default.
  #
  class Engine < Railtie
    autoload :Configurable,  "rails/engine/configurable"
    autoload :Configuration, "rails/engine/configuration"

    class << self
      attr_accessor :called_from

      # TODO Remove this. It's deprecated.
      alias :engine_name :railtie_name

      def inherited(base)
        unless base.abstract_railtie?
          base.called_from = begin
            # Remove the line number from backtraces making sure we don't leave anything behind
            call_stack = caller.map { |p| p.split(':')[0..-2].join(':') }
            File.dirname(call_stack.detect { |p| p !~ %r[railties[\w\-\.]*/lib/rails|rack[\w\-\.]*/lib/rack] })
          end
        end

        super
      end

      def find_root_with_flag(flag, default=nil)
        root_path = self.called_from

        while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
          parent = File.dirname(root_path)
          root_path = parent != root_path && parent
        end

        root = File.exist?("#{root_path}/#{flag}") ? root_path : default
        raise "Could not find root path for #{self}" unless root

        RUBY_PLATFORM =~ /mswin|mingw/ ?
          Pathname.new(root).expand_path : Pathname.new(root).realpath
      end
    end

    delegate :middleware, :paths, :root, :to => :config

    def load_tasks
      super
      config.paths.lib.tasks.to_a.sort.each { |ext| load(ext) }
    end

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path, :before => :bootstrap_load_path do
      config.load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files,
    # and the load_once paths.
    initializer :set_autoload_paths, :before => :bootstrap_load_path do |app|
      ActiveSupport::Dependencies.load_paths.unshift(*config.load_paths)

      if reloadable?(app)
        ActiveSupport::Dependencies.load_once_paths.unshift(*config.load_once_paths)
      else
        ActiveSupport::Dependencies.load_once_paths.unshift(*config.load_paths)
      end

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.load_paths.freeze
      config.load_once_paths.freeze
    end

    initializer :add_routing_paths do |app|
      paths.config.routes.to_a.each do |route|
        app.routes_reloader.paths.unshift(route) if File.exists?(route)
      end
    end

    # DEPRECATED: Remove in 3.1
    initializer :add_routing_namespaces do |app|
      paths.app.controllers.to_a.each do |load_path|
        load_path = File.expand_path(load_path)
        Dir["#{load_path}/*/**/*_controller.rb"].collect do |path|
          namespace = File.dirname(path).sub(/#{load_path}\/?/, '')
          app.routes.controller_namespaces << namespace unless namespace.empty?
        end
      end
    end

    # I18n load paths are a special case since the ones added
    # later have higher priority.
    initializer :add_locales do
      config.i18n.railties_load_path.concat(paths.config.locales.to_a)
    end

    initializer :add_view_paths do
      views = paths.app.views.to_a
      ActiveSupport.on_load(:action_controller) do
        prepend_view_path(views)
      end

      ActiveSupport.on_load(:action_mailer) do
        prepend_view_path(views)
      end
    end

    initializer :add_metals do |app|
      app.metal_loader.paths.unshift(*paths.app.metals.to_a)
    end

    initializer :load_config_initializers do
      paths.config.initializers.to_a.sort.each do |initializer|
        load(initializer)
      end
    end

    initializer :load_app_classes do |app|
      next if $rails_rake_task

      if app.config.cache_classes
        config.eager_load_paths.each do |load_path|
          matcher = /\A#{Regexp.escape(load_path)}\/(.*)\.rb\Z/
          Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
            require_dependency file.sub(matcher, '\1')
          end
        end
      end
    end

  protected

    def reloadable?(app)
      app.config.reload_engines
    end
  end
end
