require 'rails/railtie'
require 'rails/engine/railties'
require 'active_support/core_ext/module/delegation'
require 'pathname'

module Rails
  # <tt>Rails::Engine</tt> allows you to wrap a specific Rails application or subset of
  # functionality and share it with other applications or within a larger packaged application.
  # Since Rails 3.0, every <tt>Rails::Application</tt> is just an engine, which allows for simple
  # feature and application sharing.
  #
  # Any <tt>Rails::Engine</tt> is also a <tt>Rails::Railtie</tt>, so the same
  # methods (like <tt>rake_tasks</tt> and +generators+) and configuration
  # options that are available in railties can also be used in engines.
  #
  # == Creating an Engine
  #
  # In Rails versions prior to 3.0, your gems automatically behaved as engines, however,
  # this coupled Rails to Rubygems. Since Rails 3.0, if you want a gem to automatically
  # behave as an engine, you have to specify an +Engine+ for it somewhere inside
  # your plugin's +lib+ folder (similar to how we specify a +Railtie+):
  #
  #   # lib/my_engine.rb
  #   module MyEngine
  #     class Engine < Rails::Engine
  #     end
  #   end
  #
  # Then ensure that this file is loaded at the top of your <tt>config/application.rb</tt>
  # (or in your +Gemfile+) and it will automatically load models, controllers and helpers
  # inside +app+, load routes at <tt>config/routes.rb</tt>, load locales at
  # <tt>config/locales/*</tt>, and load tasks at <tt>lib/tasks/*</tt>.
  #
  # == Configuration
  #
  # Besides the +Railtie+ configuration which is shared across the application, in a
  # <tt>Rails::Engine</tt> you can access <tt>autoload_paths</tt>, <tt>eager_load_paths</tt>
  # and <tt>autoload_once_paths</tt>, which, differently from a <tt>Railtie</tt>, are scoped to
  # the current engine.
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
  # == Generators
  #
  # You can set up generators for engines with <tt>config.generators</tt> method:
  #
  #   class MyEngine < Rails::Engine
  #     config.generators do |g|
  #       g.orm             :active_record
  #       g.template_engine :erb
  #       g.test_framework  :test_unit
  #     end
  #   end
  #
  # You can also set generators for an application by using <tt>config.app_generators</tt>:
  #
  #   class MyEngine < Rails::Engine
  #     # note that you can also pass block to app_generators in the same way you
  #     # can pass it to generators method
  #     config.app_generators.orm :datamapper
  #   end
  #
  # == Paths
  #
  # Since Rails 3.0, applications and engines have more flexible path configuration (as
  # opposed to the previous hardcoded path configuration). This means that you are not
  # required to place your controllers at <tt>app/controllers</tt>, but in any place
  # which you find convenient.
  #
  # For example, let's suppose you want to place your controllers in <tt>lib/controllers</tt>.
  # You can set that as an option:
  #
  #   class MyEngine < Rails::Engine
  #     paths["app/controllers"] = "lib/controllers"
  #   end
  #
  # You can also have your controllers loaded from both <tt>app/controllers</tt> and
  # <tt>lib/controllers</tt>:
  #
  #   class MyEngine < Rails::Engine
  #     paths["app/controllers"] << "lib/controllers"
  #   end
  #
  # The available paths in an engine are:
  #
  #   class MyEngine < Rails::Engine
  #     paths["app"]                 # => ["app"]
  #     paths["app/controllers"]     # => ["app/controllers"]
  #     paths["app/helpers"]         # => ["app/helpers"]
  #     paths["app/models"]          # => ["app/models"]
  #     paths["app/views"]           # => ["app/views"]
  #     paths["lib"]                 # => ["lib"]
  #     paths["lib/tasks"]           # => ["lib/tasks"]
  #     paths["config"]              # => ["config"]
  #     paths["config/initializers"] # => ["config/initializers"]
  #     paths["config/locales"]      # => ["config/locales"]
  #     paths["config/routes.rb"]    # => ["config/routes.rb"]
  #   end
  #
  # The <tt>Application</tt> class adds a couple more paths to this set. And as in your
  # <tt>Application</tt>, all folders under +app+ are automatically added to the load path.
  # If you have an <tt>app/services</tt> folder for example, it will be added by default.
  #
  # == Endpoint
  #
  # An engine can be also a rack application. It can be useful if you have a rack application that
  # you would like to wrap with +Engine+ and provide some of the +Engine+'s features.
  #
  # To do that, use the +endpoint+ method:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       endpoint MyRackApplication
  #     end
  #   end
  #
  # Now you can mount your engine in application's routes just like that:
  #
  #   Rails.application.routes.draw do
  #     mount MyEngine::Engine => "/engine"
  #   end
  #
  # == Middleware stack
  #
  # As an engine can now be a rack endpoint, it can also have a middleware
  # stack. The usage is exactly the same as in <tt>Application</tt>:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       middleware.use SomeMiddleware
  #     end
  #   end
  #
  # == Routes
  #
  # If you don't specify an endpoint, routes will be used as the default
  # endpoint. You can use them just like you use an application's routes:
  #
  #   # ENGINE/config/routes.rb
  #   MyEngine::Engine.routes.draw do
  #     get "/" => "posts#index"
  #   end
  #
  # == Mount priority
  #
  # Note that now there can be more than one router in your application, and it's better to avoid
  # passing requests through many routers. Consider this situation:
  #
  #   Rails.application.routes.draw do
  #     mount MyEngine::Engine => "/blog"
  #     get "/blog/omg" => "main#omg"
  #   end
  #
  # +MyEngine+ is mounted at <tt>/blog</tt>, and <tt>/blog/omg</tt> points to application's
  # controller. In such a situation, requests to <tt>/blog/omg</tt> will go through +MyEngine+,
  # and if there is no such route in +Engine+'s routes, it will be dispatched to <tt>main#omg</tt>.
  # It's much better to swap that:
  #
  #   Rails.application.routes.draw do
  #     get "/blog/omg" => "main#omg"
  #     mount MyEngine::Engine => "/blog"
  #   end
  #
  # Now, +Engine+ will get only requests that were not handled by +Application+.
  #
  # == Engine name
  #
  # There are some places where an Engine's name is used:
  #
  # * routes: when you mount an Engine with <tt>mount(MyEngine::Engine => '/my_engine')</tt>,
  #   it's used as default <tt>:as</tt> option
  # * rake task for installing migrations <tt>my_engine:install:migrations</tt>
  #
  # Engine name is set by default based on class name. For <tt>MyEngine::Engine</tt> it will be
  # <tt>my_engine_engine</tt>. You can change it manually using the <tt>engine_name</tt> method:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       engine_name "my_engine"
  #     end
  #   end
  #
  # == Isolated Engine
  #
  # Normally when you create controllers, helpers and models inside an engine, they are treated
  # as if they were created inside the application itself. This means that all helpers and
  # named routes from the application will be available to your engine's controllers as well.
  #
  # However, sometimes you want to isolate your engine from the application, especially if your engine
  # has its own router. To do that, you simply need to call +isolate_namespace+. This method requires
  # you to pass a module where all your controllers, helpers and models should be nested to:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       isolate_namespace MyEngine
  #     end
  #   end
  #
  # With such an engine, everything that is inside the +MyEngine+ module will be isolated from
  # the application.
  #
  # Consider such controller:
  #
  #   module MyEngine
  #     class FooController < ActionController::Base
  #     end
  #   end
  #
  # If an engine is marked as isolated, +FooController+ has access only to helpers from +Engine+ and
  # <tt>url_helpers</tt> from <tt>MyEngine::Engine.routes</tt>.
  #
  # The next thing that changes in isolated engines is the behavior of routes. Normally, when you namespace
  # your controllers, you also need to do namespace all your routes. With an isolated engine,
  # the namespace is applied by default, so you can ignore it in routes:
  #
  #   MyEngine::Engine.routes.draw do
  #     resources :articles
  #   end
  #
  # The routes above will automatically point to <tt>MyEngine::ArticlesController</tt>. Furthermore, you don't
  # need to use longer url helpers like <tt>my_engine_articles_path</tt>. Instead, you should simply use
  # <tt>articles_path</tt> as you would do with your application.
  #
  # To make that behavior consistent with other parts of the framework, an isolated engine also has influence on
  # <tt>ActiveModel::Naming</tt>. When you use a namespaced model, like <tt>MyEngine::Article</tt>, it will normally
  # use the prefix "my_engine". In an isolated engine, the prefix will be omitted in url helpers and
  # form fields for convenience.
  #
  #   polymorphic_url(MyEngine::Article.new) # => "articles_path"
  #
  #   form_for(MyEngine::Article.new) do
  #     text_field :title # => <input type="text" name="article[title]" id="article_title" />
  #   end
  #
  # Additionally, an isolated engine will set its name according to namespace, so
  # MyEngine::Engine.engine_name will be "my_engine". It will also set MyEngine.table_name_prefix
  # to "my_engine_", changing the MyEngine::Article model to use the my_engine_articles table.
  #
  # == Using Engine's routes outside Engine
  #
  # Since you can now mount an engine inside application's routes, you do not have direct access to +Engine+'s
  # <tt>url_helpers</tt> inside +Application+. When you mount an engine in an application's routes, a special helper is
  # created to allow you to do that. Consider such a scenario:
  #
  #   # config/routes.rb
  #   Rails.application.routes.draw do
  #     mount MyEngine::Engine => "/my_engine", as: "my_engine"
  #     get "/foo" => "foo#index"
  #   end
  #
  # Now, you can use the <tt>my_engine</tt> helper inside your application:
  #
  #   class FooController < ApplicationController
  #     def index
  #       my_engine.root_url # => /my_engine/
  #     end
  #   end
  #
  # There is also a <tt>main_app</tt> helper that gives you access to application's routes inside Engine:
  #
  #   module MyEngine
  #     class BarController
  #       def index
  #         main_app.foo_path # => /foo
  #       end
  #     end
  #   end
  #
  # Note that the <tt>:as</tt> option given to mount takes the <tt>engine_name</tt> as default, so most of the time
  # you can simply omit it.
  #
  # Finally, if you want to generate a url to an engine's route using
  # <tt>polymorphic_url</tt>, you also need to pass the engine helper. Let's
  # say that you want to create a form pointing to one of the engine's routes.
  # All you need to do is pass the helper as the first element in array with
  # attributes for url:
  #
  #   form_for([my_engine, @user])
  #
  # This code will use <tt>my_engine.user_path(@user)</tt> to generate the proper route.
  #
  # == Isolated engine's helpers
  #
  # Sometimes you may want to isolate engine, but use helpers that are defined for it.
  # If you want to share just a few specific helpers you can add them to application's
  # helpers in ApplicationController:
  #
  #   class ApplicationController < ActionController::Base
  #     helper MyEngine::SharedEngineHelper
  #   end
  #
  # If you want to include all of the engine's helpers, you can use #helper method on an engine's
  # instance:
  #
  #   class ApplicationController < ActionController::Base
  #     helper MyEngine::Engine.helpers
  #   end
  #
  # It will include all of the helpers from engine's directory. Take into account that this does
  # not include helpers defined in controllers with helper_method or other similar solutions,
  # only helpers defined in the helpers directory will be included.
  #
  # == Migrations & seed data
  #
  # Engines can have their own migrations. The default path for migrations is exactly the same
  # as in application: <tt>db/migrate</tt>
  #
  # To use engine's migrations in application you can use rake task, which copies them to
  # application's dir:
  #
  #   rake ENGINE_NAME:install:migrations
  #
  # Note that some of the migrations may be skipped if a migration with the same name already exists
  # in application. In such a situation you must decide whether to leave that migration or rename the
  # migration in the application and rerun copying migrations.
  #
  # If your engine has migrations, you may also want to prepare data for the database in
  # the <tt>db/seeds.rb</tt> file. You can load that data using the <tt>load_seed</tt> method, e.g.
  #
  #   MyEngine::Engine.load_seed
  #
  # == Loading priority
  #
  # In order to change engine's priority you can use +config.railties_order+ in main application.
  # It will affect the priority of loading views, helpers, assets and all the other files
  # related to engine or application.
  #
  #   # load Blog::Engine with highest priority, followed by application and other railties
  #   config.railties_order = [Blog::Engine, :main_app, :all]
  class Engine < Railtie
    autoload :Configuration, "rails/engine/configuration"

    class << self
      attr_accessor :called_from, :isolated

      alias :isolated? :isolated
      alias :engine_name :railtie_name

      delegate :eager_load!, to: :instance

      def inherited(base)
        unless base.abstract_railtie?
          Rails::Railtie::Configuration.eager_load_namespaces << base

          base.called_from = begin
            call_stack = if Kernel.respond_to?(:caller_locations)
              caller_locations.map(&:path)
            else
              # Remove the line number from backtraces making sure we don't leave anything behind
              caller.map { |p| p.sub(/:\d+.*/, '') }
            end

            File.dirname(call_stack.detect { |p| p !~ %r[railties[\w.-]*/lib/rails|rack[\w.-]*/lib/rack] })
          end
        end

        super
      end

      def endpoint(endpoint = nil)
        @endpoint ||= nil
        @endpoint = endpoint if endpoint
        @endpoint
      end

      def isolate_namespace(mod)
        engine_name(generate_railtie_name(mod))

        self.routes.default_scope = { module: ActiveSupport::Inflector.underscore(mod.name) }
        self.isolated = true

        unless mod.respond_to?(:railtie_namespace)
          name, railtie = engine_name, self

          mod.singleton_class.instance_eval do
            define_method(:railtie_namespace) { railtie }

            unless mod.respond_to?(:table_name_prefix)
              define_method(:table_name_prefix) { "#{name}_" }
            end

            unless mod.respond_to?(:use_relative_model_naming?)
              class_eval "def use_relative_model_naming?; true; end", __FILE__, __LINE__
            end

            unless mod.respond_to?(:railtie_helpers_paths)
              define_method(:railtie_helpers_paths) { railtie.helpers_paths }
            end

            unless mod.respond_to?(:railtie_routes_url_helpers)
              define_method(:railtie_routes_url_helpers) { railtie.routes.url_helpers }
            end
          end
        end
      end

      # Finds engine with given path
      def find(path)
        expanded_path = File.expand_path path
        Rails::Engine.subclasses.each do |klass|
          engine = klass.instance
          return engine if File.expand_path(engine.root) == expanded_path
        end
        nil
      end
    end

    delegate :middleware, :root, :paths, to: :config
    delegate :engine_name, :isolated?, to: :class

    def initialize
      @_all_autoload_paths = nil
      @_all_load_paths     = nil
      @app                 = nil
      @config              = nil
      @env_config          = nil
      @helpers             = nil
      @routes              = nil
      super
    end

    # Load console and invoke the registered hooks.
    # Check <tt>Rails::Railtie.console</tt> for more info.
    def load_console(app=self)
      require "rails/console/app"
      require "rails/console/helpers"
      run_console_blocks(app)
      self
    end

    # Load Rails runner and invoke the registered hooks.
    # Check <tt>Rails::Railtie.runner</tt> for more info.
    def load_runner(app=self)
      run_runner_blocks(app)
      self
    end

    # Load Rake, railties tasks and invoke the registered hooks.
    # Check <tt>Rails::Railtie.rake_tasks</tt> for more info.
    def load_tasks(app=self)
      require "rake"
      run_tasks_blocks(app)
      self
    end

    # Load Rails generators and invoke the registered hooks.
    # Check <tt>Rails::Railtie.generators</tt> for more info.
    def load_generators(app=self)
      require "rails/generators"
      run_generators_blocks(app)
      Rails::Generators.configure!(app.config.generators)
      self
    end

    # Eager load the application by loading all ruby
    # files inside eager_load paths.
    def eager_load!
      config.eager_load_paths.each do |load_path|
        matcher = /\A#{Regexp.escape(load_path.to_s)}\/(.*)\.rb\Z/
        Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
          require_dependency file.sub(matcher, '\1')
        end
      end
    end

    def railties
      @railties ||= Railties.new
    end

    # Returns a module with all the helpers defined for the engine.
    def helpers
      @helpers ||= begin
        helpers = Module.new
        all = ActionController::Base.all_helpers_from_path(helpers_paths)
        ActionController::Base.modules_for_helpers(all).each do |mod|
          helpers.send(:include, mod)
        end
        helpers
      end
    end

    # Returns all registered helpers paths.
    def helpers_paths
      paths["app/helpers"].existent
    end

    # Returns the underlying rack application for this engine.
    def app
      @app ||= begin
        config.middleware = config.middleware.merge_into(default_middleware_stack)
        config.middleware.build(endpoint)
      end
    end

    # Returns the endpoint for this engine. If none is registered,
    # defaults to an ActionDispatch::Routing::RouteSet.
    def endpoint
      self.class.endpoint || routes
    end

    # Define the Rack API for this engine.
    def call(env)
      env.merge!(env_config)
      if env['SCRIPT_NAME']
        env.merge! "ROUTES_#{routes.object_id}_SCRIPT_NAME" => env['SCRIPT_NAME'].dup
      end
      app.call(env)
    end

    # Defines additional Rack env configuration that is added on each call.
    def env_config
      @env_config ||= {
        'action_dispatch.routes' => routes
      }
    end

    # Defines the routes for this engine. If a block is given to
    # routes, it is appended to the engine.
    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
      @routes.append(&Proc.new) if block_given?
      @routes
    end

    # Define the configuration object for the engine.
    def config
      @config ||= Engine::Configuration.new(find_root_with_flag("lib"))
    end

    # Load data from db/seeds.rb file. It can be used in to load engines'
    # seeds, e.g.:
    #
    # Blog::Engine.load_seed
    def load_seed
      seed_file = paths["db/seeds.rb"].existent.first
      load(seed_file) if seed_file
    end

    # Add configured load paths to ruby load paths and remove duplicates.
    initializer :set_load_path, before: :bootstrap_hook do
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
    initializer :set_autoload_paths, before: :bootstrap_hook do
      ActiveSupport::Dependencies.autoload_paths.unshift(*_all_autoload_paths)
      ActiveSupport::Dependencies.autoload_once_paths.unshift(*_all_autoload_once_paths)

      # Freeze so future modifications will fail rather than do nothing mysteriously
      config.autoload_paths.freeze
      config.eager_load_paths.freeze
      config.autoload_once_paths.freeze
    end

    initializer :add_routing_paths do |app|
      paths = self.paths["config/routes.rb"].existent

      if routes? || paths.any?
        app.routes_reloader.paths.unshift(*paths)
        app.routes_reloader.route_sets << routes
      end
    end

    # I18n load paths are a special case since the ones added
    # later have higher priority.
    initializer :add_locales do
      config.i18n.railties_load_path.concat(paths["config/locales"].existent)
    end

    initializer :add_view_paths do
      views = paths["app/views"].existent
      unless views.empty?
        ActiveSupport.on_load(:action_controller){ prepend_view_path(views) if respond_to?(:prepend_view_path) }
        ActiveSupport.on_load(:action_mailer){ prepend_view_path(views) }
      end
    end

    initializer :load_environment_config, before: :load_environment_hook, group: :all do
      paths["config/environments"].existent.each do |environment|
        require environment
      end
    end

    initializer :append_assets_path, group: :all do |app|
      app.config.assets.paths.unshift(*paths["vendor/assets"].existent_directories)
      app.config.assets.paths.unshift(*paths["lib/assets"].existent_directories)
      app.config.assets.paths.unshift(*paths["app/assets"].existent_directories)
    end

    initializer :prepend_helpers_path do |app|
      if !isolated? || (app == self)
        app.config.helpers_paths.unshift(*paths["app/helpers"].existent)
      end
    end

    initializer :load_config_initializers do
      config.paths["config/initializers"].existent.sort.each do |initializer|
        load_config_initializer(initializer)
      end
    end

    initializer :engines_blank_point do
      # We need this initializer so all extra initializers added in engines are
      # consistently executed after all the initializers above across all engines.
    end

    rake_tasks do
      next if self.is_a?(Rails::Application)
      next unless has_migrations?

      namespace railtie_name do
        namespace :install do
          desc "Copy migrations from #{railtie_name} to application"
          task :migrations do
            ENV["FROM"] = railtie_name
            if Rake::Task.task_defined?("railties:install:migrations")
              Rake::Task["railties:install:migrations"].invoke
            else
              Rake::Task["app:railties:install:migrations"].invoke
            end
          end
        end
      end
    end

    def routes? #:nodoc:
      @routes
    end

    protected

    def load_config_initializer(initializer)
      ActiveSupport::Notifications.instrument('load_config_initializer.railties', initializer: initializer) do
        load(initializer)
      end
    end

    def run_tasks_blocks(*) #:nodoc:
      super
      paths["lib/tasks"].existent.sort.each { |ext| load(ext) }
    end

    def has_migrations? #:nodoc:
      paths["db/migrate"].existent.any?
    end

    def find_root_with_flag(flag, default=nil) #:nodoc:
      root_path = self.class.called_from

      while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
        parent = File.dirname(root_path)
        root_path = parent != root_path && parent
      end

      root = File.exist?("#{root_path}/#{flag}") ? root_path : default
      raise "Could not find root path for #{self}" unless root

      Pathname.new File.realpath root
    end

    def default_middleware_stack #:nodoc:
      ActionDispatch::MiddlewareStack.new
    end

    def _all_autoload_once_paths #:nodoc:
      config.autoload_once_paths
    end

    def _all_autoload_paths #:nodoc:
      @_all_autoload_paths ||= (config.autoload_paths + config.eager_load_paths + config.autoload_once_paths).uniq
    end

    def _all_load_paths #:nodoc:
      @_all_load_paths ||= (config.paths.load_paths + _all_autoload_paths).uniq
    end
  end
end
