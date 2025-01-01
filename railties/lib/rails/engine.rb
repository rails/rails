# frozen_string_literal: true

require "rails/railtie"
require "rails/engine/railties"
require "active_support/callbacks"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/try"
require "pathname"

module Rails
  # +Rails::Engine+ allows you to wrap a specific \Rails application or subset of
  # functionality and share it with other applications or within a larger packaged application.
  # Every Rails::Application is just an engine, which allows for simple
  # feature and application sharing.
  #
  # Any +Rails::Engine+ is also a Rails::Railtie, so the same
  # methods (like {rake_tasks}[rdoc-ref:Rails::Railtie::rake_tasks] and
  # {generators}[rdoc-ref:Rails::Railtie::generators]) and configuration
  # options that are available in railties can also be used in engines.
  #
  # == Creating an Engine
  #
  # If you want a gem to behave as an engine, you have to specify an +Engine+
  # for it somewhere inside your plugin's +lib+ folder (similar to how we
  # specify a +Railtie+):
  #
  #   # lib/my_engine.rb
  #   module MyEngine
  #     class Engine < Rails::Engine
  #     end
  #   end
  #
  # Then ensure that this file is loaded at the top of your <tt>config/application.rb</tt>
  # (or in your +Gemfile+), and it will automatically load models, controllers, and helpers
  # inside +app+, load routes at <tt>config/routes.rb</tt>, load locales at
  # <tt>config/locales/**/*</tt>, and load tasks at <tt>lib/tasks/**/*</tt>.
  #
  # == Configuration
  #
  # Like railties, engines can access a config object which contains configuration shared by
  # all railties and the application.
  # Additionally, each engine can access <tt>autoload_paths</tt>, <tt>eager_load_paths</tt> and
  # <tt>autoload_once_paths</tt> settings which are scoped to that engine.
  #
  #   class MyEngine < Rails::Engine
  #     # Add a load path for this specific Engine
  #     config.autoload_paths << File.expand_path("lib/some/path", __dir__)
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
  # Applications and engines have flexible path configuration, meaning that you
  # are not required to place your controllers at <tt>app/controllers</tt>, but
  # in any place which you find convenient.
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
  # An engine can also be a Rack application. It can be useful if you have a Rack application that
  # you would like to provide with some of the +Engine+'s features.
  #
  # To do that, use the ::endpoint method:
  #
  #   module MyEngine
  #     class Engine < Rails::Engine
  #       endpoint MyRackApplication
  #     end
  #   end
  #
  # Now you can mount your engine in application's routes:
  #
  #   Rails.application.routes.draw do
  #     mount MyEngine::Engine => "/engine"
  #   end
  #
  # == Middleware stack
  #
  # As an engine can now be a Rack endpoint, it can also have a middleware
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
  # Engine name is set by default based on class name. For +MyEngine::Engine+ it will be
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
  # Normally when you create controllers, helpers, and models inside an engine, they are treated
  # as if they were created inside the application itself. This means that all helpers and
  # named routes from the application will be available to your engine's controllers as well.
  #
  # However, sometimes you want to isolate your engine from the application, especially if your engine
  # has its own router. To do that, you simply need to call ::isolate_namespace. This method requires
  # you to pass a module where all your controllers, helpers, and models should be nested to:
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
  # Consider this controller:
  #
  #   module MyEngine
  #     class FooController < ActionController::Base
  #     end
  #   end
  #
  # If the +MyEngine+ engine is marked as isolated, +FooController+ only has
  # access to helpers from +MyEngine+, and <tt>url_helpers</tt> from
  # <tt>MyEngine::Engine.routes</tt>.
  #
  # The next thing that changes in isolated engines is the behavior of routes.
  # Normally, when you namespace your controllers, you also need to namespace
  # the related routes. With an isolated engine, the engine's namespace is
  # automatically applied, so you don't need to specify it explicitly in your
  # routes:
  #
  #   MyEngine::Engine.routes.draw do
  #     resources :articles
  #   end
  #
  # If +MyEngine+ is isolated, the routes above will point to
  # +MyEngine::ArticlesController+. You also don't need to use longer
  # URL helpers like +my_engine_articles_path+. Instead, you should simply use
  # +articles_path+, like you would do with your main application.
  #
  # To make this behavior consistent with other parts of the framework,
  # isolated engines also have an effect on ActiveModel::Naming. In a
  # normal \Rails app, when you use a namespaced model such as
  # +Namespace::Article+, ActiveModel::Naming will generate
  # names with the prefix "namespace". In an isolated engine, the prefix will
  # be omitted in URL helpers and form fields, for convenience.
  #
  #   polymorphic_url(MyEngine::Article.new)
  #   # => "articles_path" # not "my_engine_articles_path"
  #
  #   form_with(model: MyEngine::Article.new) do
  #     text_field :title # => <input type="text" name="article[title]" id="article_title" />
  #   end
  #
  # Additionally, an isolated engine will set its own name according to its
  # namespace, so <tt>MyEngine::Engine.engine_name</tt> will return
  # "my_engine". It will also set +MyEngine.table_name_prefix+ to "my_engine_",
  # meaning for example that +MyEngine::Article+ will use the
  # +my_engine_articles+ database table by default.
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
  # Finally, if you want to generate a URL to an engine's route using
  # <tt>polymorphic_url</tt>, you also need to pass the engine helper. Let's
  # say that you want to create a form pointing to one of the engine's routes.
  # All you need to do is pass the helper as the first element in array with
  # attributes for URL:
  #
  #   form_with(model: [my_engine, @user])
  #
  # This code will use <tt>my_engine.user_path(@user)</tt> to generate the proper route.
  #
  # == Isolated engine's helpers
  #
  # Sometimes you may want to isolate an engine, but use helpers that are defined for it.
  # If you want to share just a few specific helpers you can add them to application's
  # helpers in ApplicationController:
  #
  #   class ApplicationController < ActionController::Base
  #     helper MyEngine::SharedEngineHelper
  #   end
  #
  # If you want to include all of the engine's helpers, you can use the #helper method on an engine's
  # instance:
  #
  #   class ApplicationController < ActionController::Base
  #     helper MyEngine::Engine.helpers
  #   end
  #
  # It will include all of the helpers from engine's directory. Take into account this does
  # not include helpers defined in controllers with helper_method or other similar solutions,
  # only helpers defined in the helpers directory will be included.
  #
  # == Migrations & seed data
  #
  # Engines can have their own migrations. The default path for migrations is exactly the same
  # as in application: <tt>db/migrate</tt>
  #
  # To use engine's migrations in application you can use the rake task below, which copies them to
  # application's dir:
  #
  #   $ rake ENGINE_NAME:install:migrations
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
  # In order to change engine's priority you can use +config.railties_order+ in the main application.
  # It will affect the priority of loading views, helpers, assets, and all the other files
  # related to engine or application.
  #
  #   # load Blog::Engine with highest priority, followed by application and other railties
  #   config.railties_order = [Blog::Engine, :main_app, :all]
  class Engine < Railtie
    autoload :Configuration, "rails/engine/configuration"
    autoload :LazyRouteSet,  "rails/engine/lazy_route_set"

    class << self
      attr_accessor :called_from, :isolated

      alias :isolated? :isolated
      alias :engine_name :railtie_name

      delegate :eager_load!, to: :instance

      def inherited(base)
        unless base.abstract_railtie?
          Rails::Railtie::Configuration.eager_load_namespaces << base

          base.called_from = begin
            call_stack = caller_locations.map { |l| l.absolute_path || l.path }

            File.dirname(call_stack.detect { |p| !p.match?(%r[railties[\w.-]*/lib/rails|rack[\w.-]*/lib/rack]) })
          end
        end

        super
      end

      def find_root(from)
        find_root_with_flag "lib", from
      end

      def endpoint(endpoint = nil)
        @endpoint ||= nil
        @endpoint = endpoint if endpoint
        @endpoint
      end

      def isolate_namespace(mod)
        engine_name(generate_railtie_name(mod.name))

        config.default_scope = { module: ActiveSupport::Inflector.underscore(mod.name) }

        self.isolated = true

        unless mod.respond_to?(:railtie_namespace)
          name, railtie = engine_name, self

          mod.singleton_class.instance_eval do
            define_method(:railtie_namespace) { railtie }

            unless mod.respond_to?(:table_name_prefix)
              define_method(:table_name_prefix) { "#{name}_" }

              ActiveSupport.on_load(:active_record) do
                mod.singleton_class.redefine_method(:table_name_prefix) do
                  "#{ActiveRecord::Base.table_name_prefix}#{name}_"
                end
              end
            end

            unless mod.respond_to?(:use_relative_model_naming?)
              class_eval "def use_relative_model_naming?; true; end", __FILE__, __LINE__
            end

            unless mod.respond_to?(:railtie_helpers_paths)
              define_method(:railtie_helpers_paths) { railtie.helpers_paths }
            end

            unless mod.respond_to?(:railtie_routes_url_helpers)
              define_method(:railtie_routes_url_helpers) { |include_path_helpers = true| railtie.routes.url_helpers(include_path_helpers) }
            end
          end
        end
      end

      # Finds engine with given path.
      def find(path)
        expanded_path = File.expand_path path
        Rails::Engine.subclasses.each do |klass|
          engine = klass.instance
          return engine if File.expand_path(engine.root) == expanded_path
        end
        nil
      end
    end

    include ActiveSupport::Callbacks
    define_callbacks :load_seed

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
      @app_build_lock      = Mutex.new
      super
    end

    # Load console and invoke the registered hooks.
    # Check Rails::Railtie.console for more info.
    def load_console(app = self)
      run_console_blocks(app)
      self
    end

    # Load \Rails runner and invoke the registered hooks.
    # Check Rails::Railtie.runner for more info.
    def load_runner(app = self)
      run_runner_blocks(app)
      self
    end

    # Load Rake and railties tasks, and invoke the registered hooks.
    # Check Rails::Railtie.rake_tasks for more info.
    def load_tasks(app = self)
      require "rake"
      run_tasks_blocks(app)
      self
    end

    # Load \Rails generators and invoke the registered hooks.
    # Check Rails::Railtie.generators for more info.
    def load_generators(app = self)
      require "rails/generators"
      run_generators_blocks(app)
      Rails::Generators.configure!(app.config.generators)
      self
    end

    # Invoke the server registered hooks.
    # Check Rails::Railtie.server for more info.
    def load_server(app = self)
      run_server_blocks(app)
      self
    end

    def eager_load!
      # Already done by Zeitwerk::Loader.eager_load_all. By now, we leave the
      # method as a no-op for backwards compatibility.
    end

    def railties
      @railties ||= Railties.new
    end

    # Returns a module with all the helpers defined for the engine.
    def helpers
      @helpers ||= begin
        helpers = Module.new
        AbstractController::Helpers.helper_modules_from_paths(helpers_paths).each do |mod|
          helpers.include(mod)
        end
        helpers
      end
    end

    # Returns all registered helpers paths.
    def helpers_paths
      paths["app/helpers"].existent
    end

    # Returns the underlying Rack application for this engine.
    def app
      @app || @app_build_lock.synchronize {
        @app ||= begin
          stack = default_middleware_stack
          config.middleware = build_middleware.merge_into(stack)
          config.middleware.build(endpoint)
        end
      }
    end

    # Returns the endpoint for this engine. If none is registered,
    # defaults to an ActionDispatch::Routing::RouteSet.
    def endpoint
      self.class.endpoint || routes
    end

    # Define the Rack API for this engine.
    def call(env)
      req = build_request env
      app.call req.env
    end

    # Defines additional Rack env configuration that is added on each call.
    def env_config
      @env_config ||= {}
    end

    # Defines the routes for this engine. If a block is given to
    # routes, it is appended to the engine.
    def routes(&block)
      @routes ||= config.route_set_class.new_with_config(config)
      @routes.append(&block) if block_given?
      @routes
    end

    # Define the configuration object for the engine.
    def config
      @config ||= Engine::Configuration.new(self.class.find_root(self.class.called_from))
    end

    # Load data from db/seeds.rb file. It can be used in to load engines'
    # seeds, e.g.:
    #
    # Blog::Engine.load_seed
    def load_seed
      seed_file = paths["db/seeds.rb"].existent.first
      run_callbacks(:load_seed) { load(seed_file) } if seed_file
    end

    initializer :load_environment_config, before: :load_environment_hook, group: :all do
      paths["config/environments"].existent.each do |environment|
        require environment
      end
    end

    initializer :set_load_path, before: :bootstrap_hook do |app|
      _all_load_paths(app.config.add_autoload_paths_to_load_path).reverse_each do |path|
        $LOAD_PATH.unshift(path) if File.directory?(path)
      end
      $LOAD_PATH.uniq!
    end

    initializer :set_autoload_paths, before: :bootstrap_hook do
      ActiveSupport::Dependencies.autoload_paths.unshift(*_all_autoload_paths)
      ActiveSupport::Dependencies.autoload_once_paths.unshift(*_all_autoload_once_paths)

      config.autoload_paths.freeze
      config.autoload_once_paths.freeze
    end

    initializer :set_eager_load_paths, before: :bootstrap_hook do
      ActiveSupport::Dependencies._eager_load_paths.merge(config.all_eager_load_paths)
      config.eager_load_paths.freeze
    end

    initializer :make_routes_lazy, before: :bootstrap_hook do |app|
      config.route_set_class = LazyRouteSet if Rails.env.local?
    end

    initializer :add_routing_paths do |app|
      routing_paths = paths["config/routes.rb"].existent
      external_paths = self.paths["config/routes"].paths
      routes.draw_paths.concat(external_paths)
      app.routes.draw_paths.concat(external_paths)

      if routes? || routing_paths.any?
        app.routes_reloader.paths.unshift(*routing_paths)
        app.routes_reloader.route_sets << routes
        app.routes_reloader.external_routes.unshift(*external_paths)
      end
    end

    # I18n load paths are a special case since the ones added
    # later have higher priority.
    initializer :add_locales do
      config.i18n.railties_load_path << paths["config/locales"]
    end

    initializer :add_view_paths do
      views = paths["app/views"].existent
      unless views.empty?
        ActiveSupport.on_load(:action_controller) { prepend_view_path(views) if respond_to?(:prepend_view_path) }
        ActiveSupport.on_load(:action_mailer) { prepend_view_path(views) }
      end
    end

    initializer :add_mailer_preview_paths do
      previews = paths["test/mailers/previews"].existent
      unless previews.empty?
        ActiveSupport.on_load(:action_mailer) { self.preview_paths |= previews }
      end
    end

    initializer :add_fixture_paths do
      next if is_a?(Rails::Application)

      fixtures = config.root.join("test", "fixtures")
      if fixtures_in_root_and_not_in_vendor_or_dot_dir?(fixtures)
        ActiveSupport.on_load(:active_record_fixtures) { self.fixture_paths |= ["#{fixtures}/"] }
      end
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

    initializer :wrap_reloader_around_load_seed do |app|
      self.class.set_callback(:load_seed, :around) do |engine, seeds_block|
        app.reloader.wrap(&seeds_block)
      end
    end

    initializer :engines_blank_point do
      # We need this initializer so all extra initializers added in engines are
      # consistently executed after all the initializers above across all engines.
    end

    rake_tasks do
      next if is_a?(Rails::Application)
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

    def routes? # :nodoc:
      @routes
    end

    protected
      def run_tasks_blocks(*) # :nodoc:
        super
        paths["lib/tasks"].existent.sort.each { |ext| load(ext) }
      end

    private
      def load_config_initializer(initializer) # :doc:
        ActiveSupport::Notifications.instrument("load_config_initializer.railties", initializer: initializer) do
          load(initializer)
        end
      end

      def has_migrations?
        paths["db/migrate"].existent.any?
      end

      def self.find_root_with_flag(flag, root_path, default = nil) # :nodoc:
        while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
          parent = File.dirname(root_path)
          root_path = parent != root_path && parent
        end

        root = File.exist?("#{root_path}/#{flag}") ? root_path : default
        raise "Could not find root path for #{self}" unless root

        Pathname.new File.realpath root
      end

      def default_middleware_stack
        ActionDispatch::MiddlewareStack.new
      end

      def _all_autoload_once_paths
        config.all_autoload_once_paths.uniq
      end

      def _all_autoload_paths
        @_all_autoload_paths ||= begin
          autoload_paths  = config.all_autoload_paths
          autoload_paths += config.all_eager_load_paths
          autoload_paths -= config.all_autoload_once_paths
          autoload_paths.uniq
        end
      end

      def _all_load_paths(add_autoload_paths_to_load_path)
        @_all_load_paths ||= begin
          load_paths = config.paths.load_paths
          if add_autoload_paths_to_load_path
            load_paths += _all_autoload_paths
            load_paths += _all_autoload_once_paths
          end
          load_paths.uniq
        end
      end

      def fixtures_in_root_and_not_in_vendor_or_dot_dir?(fixtures)
        fixtures.exist? && fixtures.to_s.start_with?(Rails.root.to_s) &&
          !fixtures.to_s.start_with?(Rails.root.join("vendor").to_s) &&
          !fixtures.to_s.start_with?("#{Rails.root}/.".to_s)
      end

      def build_request(env)
        env.merge!(env_config)
        req = ActionDispatch::Request.new env
        req.routes = routes
        req.engine_script_name = req.script_name
        req
      end

      def build_middleware
        config.middleware
      end
  end
end
