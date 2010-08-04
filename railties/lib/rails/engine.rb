require 'rails/railtie'
require 'active_support/core_ext/module/delegation'
require 'pathname'
require 'rbconfig'
require 'rails/engine/railties'

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
  # your Gemfile) and it will automatically load models, controllers and helpers
  # inside app, load routes at "config/routes.rb", load locales at "config/locales/*",
  # load tasks at "lib/tasks/*".
  #
  # == Configuration
  #
  # Besides the Railtie configuration which is shared across the application, in a
  # Rails::Engine you can access autoload_paths, eager_load_paths and autoload_once_paths,
  # which differently from a Railtie, are scoped to the current Engine.
  #
  # Example:
  #
  #   class MyEngine < Rails::Engine
  #     # Add a load path for this specific Engine
  #     config.autoload_paths << File.expand_path("../lib/some/path", __FILE__)
  #
  #     initializer "my_engine.add_middleware" do |app|
  #       app.middleware.use MyEngine::Middleware
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
  # == Endpoint
  #
  # Engine can be also a rack application. It can be useful if you have a rack application that
  # you would like to wrap with Engine and provide some of the Engine's features.
  #
  # To do that, use endpoint method:
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       endpoint MyRackApplication
  #     end
  #   end
  #
  # Now you can mount your engine in application's routes just like that:
  #
  # MyRailsApp::Application.routes.draw do
  #   mount MyEngine::Engine => "/engine"
  # end
  #
  # == Middleware stack
  #
  # As Engine can now be rack endpoint, it can also have a middleware stack. The usage is exactly
  # the same as in application:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       middleware.use SomeMiddleware
  #     end
  #   end
  #
  # == Routes
  #
  # If you don't specify endpoint, routes will be used as default endpoint. You can use them
  # just like you use application's routes:
  #
  # # ENGINE/config/routes.rb
  # MyEngine::Engine.routes.draw do
  #   match "/" => "posts#index"
  # end
  #
  # == Mount priority
  #
  # Note that now there can be more than one router in you application and it's better to avoid
  # passing requests through many routers. Consider such situation:
  #
  # MyRailsApp::Application.routes.draw do
  #   mount MyEngine::Engine => "/blog"
  #   match "/blog/omg" => "main#omg"
  # end
  #
  # MyEngine is mounted at "/blog" path and additionaly "/blog/omg" points application's controller.
  # In such situation request to "/blog/omg" will go through MyEngine and if there is no such route
  # in Engine's routes, it will be dispatched to "main#omg". It's much better to swap that:
  #
  # MyRailsApp::Application.routes.draw do
  #   match "/blog/omg" => "main#omg"
  #   mount MyEngine::Engine => "/blog"
  # end
  #
  # Now, Engine will get only requests that were not handled by application.
  #
  # == Asset path
  #
  # When you use engine with its own public directory, you will probably want to copy or symlink it
  # to application's public directory. To simplify generating paths for assets, you can set asset_path
  # for an Engine:
  #
  # module MyEngine
  #   class Engine < Rails::Engine
  #     config.asset_path = "/my_engine/%s"
  #   end
  # end
  #
  # With such config, asset paths will be automatically modified inside Engine:
  # image_path("foo.jpg") #=> "/my_engine/images/foo.jpg"
  #
  # == Engine name
  #
  # There are some places where engine's name is used.
  # * routes: when you mount engine with mount(MyEngine::Engine => '/my_engine'), it's used as default :as option
  # * migrations: when you copy engine's migrations, they will be decorated with suffix based on engine_name, for example:
  #   2010010203121314_create_users.my_engine.rb
  #
  # Engine name is set by default based on class name. For MyEngine::Engine it will be my_engine_engine.
  # You can change it manually it manually using engine_name method:
  #
  # module MyEngine
  #   class Engine < Rails::Engine
  #     engine_name "my_engine"
  #   end
  # end
  #
  # == Namespaced Engine
  #
  # Normally, when you create controllers, helpers and models inside engine, they are treated
  # as they would be created inside application. One of the cosequences of that is including
  # application's helpers and url_helpers inside controller. Sometimes, especially when your
  # engine provides its own routes, you don't want that. To isolate engine's stuff from application
  # you can use namespace method:
  #
  # module MyEngine
  #   class Engine < Rails::Engine
  #     namespace MyEngine
  #   end
  # end
  #
  # With such Engine, everything that is inside MyEngine module, will be isolated from application.
  #
  # Consider such controller:
  #
  # module MyEngine
  #   class FooController < ActionController::Base
  #   end
  # end
  #
  # If engine is marked as namespaced, FooController has access only to helpers from engine and
  # url_helpers from MyEngine::Engine.routes.
  #
  # Additionaly namespaced engine will set its name according to namespace, so in that case:
  # MyEngine::Engine.engine_name #=> "my_engine"
  # and it will set MyEngine.table_name_prefix to "my_engine_"
  #
  # == Using Engine's routes outside Engine
  #
  # Since you can mount engine inside application's routes now, you do not have direct access to engine's
  # url_helpers inside application. When you mount Engine in application's routes special helper is
  # created to allow doing that. Consider such scenario:
  #
  # # APP/config/routes.rb
  # MyApplication::Application.routes.draw do
  #   mount MyEngine::Engine => "/my_engine", :as => "my_engine"
  #   match "/foo" => "foo#index"
  # end
  #
  # Now, you can use my_engine helper:
  #
  # class FooController < ApplicationController
  #   def index
  #     my_engine.root_url #=> /my_engine/
  #   end
  # end
  #
  # There is also 'app' helper that gives you access to application's routes inside Engine:
  #
  # module MyEngine
  #   class BarController
  #     app.foo_path #=> /foo
  #   end
  # end
  #
  # Note that :as option takes engine_name as default, so most of the time you can ommit it.
  class Engine < Railtie
    autoload :Configurable,  "rails/engine/configurable"
    autoload :Configuration, "rails/engine/configuration"

    class << self
      attr_accessor :called_from
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

        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ?
          Pathname.new(root).expand_path : Pathname.new(root).realpath
      end

      def endpoint(endpoint = nil)
        @endpoint = endpoint if endpoint
        @endpoint
      end

      def namespace(mod)
        # TODO: extract that into a module
        engine_name(generate_railtie_name(mod))

        _railtie = self
        name = engine_name
        mod.singleton_class.instance_eval do
          define_method(:_railtie) do
            _railtie
          end

          define_method(:table_name_prefix) do
            "#{name}_"
          end
        end
      end
    end

    delegate :middleware, :root, :paths, :to => :config
    delegate :engine_name, :to => "self.class"

    def load_tasks
      super
      config.paths.lib.tasks.to_a.sort.each { |ext| load(ext) }
    end

    def eager_load!
      config.eager_load_paths.each do |load_path|
        matcher = /\A#{Regexp.escape(load_path)}\/(.*)\.rb\Z/
        Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
          require_dependency file.sub(matcher, '\1')
        end
      end
    end

    def railties
      @railties ||= self.class::Railties.new(config)
    end

    def app
      @app ||= begin
        config.middleware = config.middleware.merge_into(default_middleware_stack)
        config.middleware.build(endpoint)
      end
    end

    def endpoint
      self.class.endpoint || routes
    end

    def call(env)
      app.call(env.merge!(env_config))
    end

    def env_config
      @env_config ||= {
        'action_dispatch.routes' => routes,
        'action_dispatch.asset_path' => config.asset_path
      }
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    def initializers
      initializers = []
      railties.all { |r| initializers += r.initializers }
      initializers += super
      initializers
    end

    def config
      @config ||= Engine::Configuration.new(find_root_with_flag("lib"))
    end

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path, :before => :bootstrap_hook do
      _all_load_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    # Set the paths from which Rails will automatically load source files,
    # and the load_once paths.
    #
    # This needs to be an initializer, since it needs to run once
    # per engine and get the engine as a block parameter
    initializer :set_autoload_paths, :before => :bootstrap_hook do |app|
      ActiveSupport::Dependencies.autoload_paths.unshift(*_all_autoload_paths)
      ActiveSupport::Dependencies.autoload_once_paths.unshift(*config.autoload_once_paths)

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.autoload_paths.freeze
      config.eager_load_paths.freeze
      config.autoload_once_paths.freeze
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
          namespace = File.dirname(path).sub(/#{Regexp.escape(load_path)}\/?/, '')
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

    initializer :load_config_initializers do
      paths.config.initializers.to_a.sort.each do |initializer|
        load(initializer)
      end
    end

    initializer :engines_blank_point do
      # We need this initializer so all extra initializers added in engines are
      # consistently executed after all the initializers above across all engines.
    end

    initializer :load_environment_config, :before => :load_environment_hook do
      environment = config.paths.config.environments.to_a.first
      require environment if environment
    end

    initializer :default_asset_path do
      config.asset_path = "/#{engine_name}%s" unless config.asset_path
    end

    initializer :append_asset_paths do
      public_path = config.paths.public.to_a.first
      if config.compiled_asset_path && File.exist?(public_path)
        config.static_asset_paths[config.compiled_asset_path] = public_path
      end
    end
  protected
    def find_root_with_flag(flag, default=nil)
      root_path = self.class.called_from

      while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
        parent = File.dirname(root_path)
        root_path = parent != root_path && parent
      end

      root = File.exist?("#{root_path}/#{flag}") ? root_path : default
      raise "Could not find root path for #{self}" unless root

      Config::CONFIG['host_os'] =~ /mswin|mingw/ ?
        Pathname.new(root).expand_path : Pathname.new(root).realpath
    end

    def default_middleware_stack
      ActionDispatch::MiddlewareStack.new
    end

    def _all_autoload_paths
      @_all_autoload_paths ||= (config.autoload_paths + config.eager_load_paths + config.autoload_once_paths).uniq
    end

    def _all_load_paths
      @_all_load_paths ||= (config.paths.load_paths + _all_autoload_paths).uniq
    end
  end
end
