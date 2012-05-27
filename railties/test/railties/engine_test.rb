require "isolation/abstract_unit"
require "railties/shared_tests"
require "stringio"
require "rack/test"

module RailtiesTest
  class EngineTest < Test::Unit::TestCase

    include ActiveSupport::Testing::Isolation
    include SharedTests
    include Rack::Test::Methods

    def setup
      build_app

      @plugin = engine "bukkits" do |plugin|
        plugin.write "lib/bukkits.rb", <<-RUBY
          module Bukkits
            class Engine < ::Rails::Engine
              railtie_name "bukkits"
            end
          end
        RUBY
        plugin.write "lib/another.rb", "class Another; end"
      end
    end

    def teardown
      teardown_app
    end

    test "Rails::Engine itself does not respond to config" do
      boot_rails
      assert !Rails::Engine.respond_to?(:config)
    end

    test "initializers are executed after application configuration initializers" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            initializer "dummy_initializer" do
            end
          end
        end
      RUBY

      boot_rails

      initializers = Rails.application.initializers.tsort
      index        = initializers.index { |i| i.name == "dummy_initializer" }
      selection    = initializers[(index-3)..(index)].map(&:name).map(&:to_s)

      assert_equal %w(
       load_config_initializers
       load_config_initializers
       engines_blank_point
       dummy_initializer
      ), selection

      assert index < initializers.index { |i| i.name == :build_middleware_stack }
    end


    class Upcaser
      def initialize(app)
        @app = app
      end

      def call(env)
        response = @app.call(env)
        response[2].each { |b| b.upcase! }
        response
      end
    end

    test "engine is a rack app and can have his own middleware stack" do
      add_to_config("config.action_dispatch.show_exceptions = false")

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, ['Hello World']] }
            config.middleware.use ::RailtiesTest::EngineTest::Upcaser
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          mount(Bukkits::Engine => "/bukkits")
        end
      RUBY

      boot_rails

      get("/bukkits")
      assert_equal "HELLO WORLD", last_response.body
    end

    test "pass the value of the segment" do
      controller "foo", <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => params[:username]
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          root :to => "foo#index"
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount(Bukkits::Engine => "/:username")
        end
      RUBY

      boot_rails

      get("/arunagw")
      assert_equal "arunagw", last_response.body

    end

    test "it provides routes as default endpoint" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/foo" => lambda { |env| [200, {'Content-Type' => 'text/html'}, ['foo']] }
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount(Bukkits::Engine => "/bukkits")
        end
      RUBY

      boot_rails

      get("/bukkits/foo")
      assert_equal "foo", last_response.body
    end

    test "engine can load its own plugins" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.yaffle_loaded = true
      RUBY

      boot_rails

      assert Bukkits::Engine.config.yaffle_loaded
    end

    test "engine does not load plugins that already exists in application" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.engine_yaffle_loaded = true
      RUBY

      app_file "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.app_yaffle_loaded = true
      RUBY

      warnings = capture(:stderr) { boot_rails }

      assert !warnings.empty?
      assert !Bukkits::Engine.config.respond_to?(:engine_yaffle_loaded)
      assert Rails.application.config.app_yaffle_loaded
    end

    test "it loads its environment file" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "config/environments/development.rb", <<-RUBY
        Bukkits::Engine.configure do
          config.environment_loaded = true
        end
      RUBY

      boot_rails

      assert Bukkits::Engine.config.environment_loaded
    end

    test "it passes router in env" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, 'hello'] }
          end
        end
      RUBY

      require "rack/file"
      boot_rails

      env = Rack::MockRequest.env_for("/")
      Bukkits::Engine.call(env)
      assert_equal Bukkits::Engine.routes, env['action_dispatch.routes']

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_equal Rails.application.routes, env['action_dispatch.routes']
    end

    test "isolated engine should include only its own routes and helpers" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      @plugin.write "app/models/bukkits/post.rb", <<-RUBY
        module Bukkits
          class Post
            extend ActiveModel::Naming

            def to_param
              "1"
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match "/bar" => "bar#index", :as => "bar"
          mount Bukkits::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/foo" => "foo#index", :as => "foo"
          match "/foo/show" => "foo#show"
          match "/from_app" => "foo#from_app"
          match "/routes_helpers_in_view" => "foo#routes_helpers_in_view"
          match "/polymorphic_path_without_namespace" => "foo#polymorphic_path_without_namespace"
          resources :posts
        end
      RUBY

      app_file "app/helpers/some_helper.rb", <<-RUBY
        module SomeHelper
          def something
            "Something... Something... Something..."
          end
        end
      RUBY

      @plugin.write "app/helpers/engine_helper.rb", <<-RUBY
        module EngineHelper
          def help_the_engine
            "Helped."
          end
        end
      RUBY

      @plugin.write "app/controllers/bukkits/foo_controller.rb", <<-RUBY
        class Bukkits::FooController < ActionController::Base
          def index
            render :inline => "<%= help_the_engine %>"
          end

          def show
            render :text => foo_path
          end

          def from_app
            render :inline => "<%= (self.respond_to?(:bar_path) || self.respond_to?(:something)) %>"
          end

          def routes_helpers_in_view
            render :inline => "<%= foo_path %>, <%= main_app.bar_path %>"
          end

          def polymorphic_path_without_namespace
            render :text => polymorphic_path(Post.new)
          end
        end
      RUBY

      @plugin.write "app/mailers/bukkits/my_mailer.rb", <<-RUBY
        module Bukkits
          class MyMailer < ActionMailer::Base
          end
        end
      RUBY

      add_to_config("config.action_dispatch.show_exceptions = false")

      boot_rails

      assert_equal "bukkits_", Bukkits.table_name_prefix
      assert_equal "bukkits", Bukkits::Engine.engine_name
      assert_equal Bukkits.railtie_namespace, Bukkits::Engine
      assert ::Bukkits::MyMailer.method_defined?(:foo_path)
      assert !::Bukkits::MyMailer.method_defined?(:bar_path)

      get("/bukkits/from_app")
      assert_equal "false", last_response.body

      get("/bukkits/foo/show")
      assert_equal "/bukkits/foo", last_response.body

      get("/bukkits/foo")
      assert_equal "Helped.", last_response.body

      get("/bukkits/routes_helpers_in_view")
      assert_equal "/bukkits/foo, /bar", last_response.body

      get("/bukkits/polymorphic_path_without_namespace")
      assert_equal "/bukkits/posts/1", last_response.body
    end

    test "isolated engine should avoid namespace in names if that's possible" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      @plugin.write "app/models/bukkits/post.rb", <<-RUBY
        module Bukkits
          class Post
            extend ActiveModel::Naming
            include ActiveModel::Conversion
            attr_accessor :title

            def to_param
              "1"
            end

            def persisted?
              false
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          mount Bukkits::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          resources :posts
        end
      RUBY

      @plugin.write "app/controllers/bukkits/posts_controller.rb", <<-RUBY
        class Bukkits::PostsController < ActionController::Base
          def new
          end
        end
      RUBY

      @plugin.write "app/views/bukkits/posts/new.html.erb", <<-ERB
          <%= form_for(Bukkits::Post.new) do |f| %>
            <%= f.text_field :title %>
          <% end %>
      ERB

      add_to_config("config.action_dispatch.show_exceptions = false")

      boot_rails

      get("/bukkits/posts/new")
      assert_match(/name="post\[title\]"/, last_response.body)
    end

    test "isolated engine should set correct route module prefix for nested namespace" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          module Awesome
            class Engine < ::Rails::Engine
              isolate_namespace Bukkits::Awesome
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          mount Bukkits::Awesome::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Awesome::Engine.routes.draw do
          match "/foo" => "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/bukkits/awesome/foo_controller.rb", <<-RUBY
        class Bukkits::Awesome::FooController < ActionController::Base
          def index
            render :text => "ok"
          end
        end
      RUBY

      add_to_config("config.action_dispatch.show_exceptions = false")

      boot_rails

      get("/bukkits/foo")
      assert_equal "ok", last_response.body
    end

    test "loading seed data" do
      @plugin.write "db/seeds.rb", <<-RUBY
        Bukkits::Engine.config.bukkits_seeds_loaded = true
      RUBY

      app_file "db/seeds.rb", <<-RUBY
        Rails.application.config.app_seeds_loaded = true
      RUBY

      boot_rails

      Rails.application.load_seed
      assert Rails.application.config.app_seeds_loaded
      assert_raise(NoMethodError) { Bukkits::Engine.config.bukkits_seeds_loaded }

      Bukkits::Engine.load_seed
      assert Bukkits::Engine.config.bukkits_seeds_loaded
    end

    test "skips nonexistent seed data" do
      FileUtils.rm "#{app_path}/db/seeds.rb"
      boot_rails
      assert_nil Rails.application.load_seed
    end

    test "using namespace more than once on one module should not overwrite railtie_namespace method" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module AppTemplate
          class Engine < ::Rails::Engine
            isolate_namespace(AppTemplate)
          end
        end
      RUBY

      add_to_config "isolate_namespace AppTemplate"

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do end
      RUBY

      boot_rails

      assert_equal AppTemplate.railtie_namespace, AppTemplate::Engine
    end

    test "properly reload routes" do
      # when routes are inside application class definition
      # they should not be reloaded when engine's routes
      # file has changed
      add_to_config <<-RUBY
        routes do
          mount lambda{|env| [200, {}, ["foo"]]} => "/foo"
          mount Bukkits::Engine => "/bukkits"
        end
      RUBY

      FileUtils.rm(File.join(app_path, "config/routes.rb"))

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          mount lambda{|env| [200, {}, ["bar"]]} => "/bar"
        end
      RUBY

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace(Bukkits)
          end
        end
      RUBY

      boot_rails

      require "#{rails_root}/config/environment"

      get("/foo")
      assert_equal "foo", last_response.body

      get("/bukkits/bar")
      assert_equal "bar", last_response.body
    end

    test "setting generators for engine and overriding app generator's" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            config.generators do |g|
              g.orm             :datamapper
              g.template_engine :haml
              g.test_framework  :rspec
            end

            config.app_generators do |g|
              g.orm             :mongoid
              g.template_engine :liquid
              g.test_framework  :shoulda
            end
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.generators do |g|
          g.test_framework  :test_unit
        end
      RUBY

      boot_rails
      require "#{rails_root}/config/environment"

      app_generators = Rails.application.config.generators.options[:rails]
      assert_equal :mongoid  , app_generators[:orm]
      assert_equal :liquid   , app_generators[:template_engine]
      assert_equal :test_unit, app_generators[:test_framework]

      generators = Bukkits::Engine.config.generators.options[:rails]
      assert_equal :datamapper, generators[:orm]
      assert_equal :haml      , generators[:template_engine]
      assert_equal :rspec     , generators[:test_framework]
    end

    test "engine should get default generators with ability to overwrite them" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            config.generators.test_framework :rspec
          end
        end
      RUBY

      boot_rails
      require "#{rails_root}/config/environment"

      generators = Bukkits::Engine.config.generators.options[:rails]
      assert_equal :active_record, generators[:orm]
      assert_equal :rspec        , generators[:test_framework]

      app_generators = Rails.application.config.generators.options[:rails]
      assert_equal :test_unit    , app_generators[:test_framework]
    end

    test "do not create table_name_prefix method if it already exists" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          def self.table_name_prefix
            "foo"
          end

          class Engine < ::Rails::Engine
            isolate_namespace(Bukkits)
          end
        end
      RUBY

      boot_rails
      require "#{rails_root}/config/environment"

      assert_equal "foo", Bukkits.table_name_prefix
    end

    test "fetching engine by path" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      boot_rails
      require "#{rails_root}/config/environment"

      assert_equal Bukkits::Engine.instance, Rails::Engine.find(@plugin.path)

      # check expanding paths
      engine_dir = @plugin.path.chomp("/").split("/").last
      engine_path = File.join(@plugin.path, '..', engine_dir)
      assert_equal Bukkits::Engine.instance, Rails::Engine.find(engine_path)
    end

    test "gather isolated engine's helpers in Engine#helpers" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      app_file "app/helpers/some_helper.rb", <<-RUBY
        module SomeHelper
          def foo
            'foo'
          end
        end
      RUBY

      @plugin.write "app/helpers/bukkits/engine_helper.rb", <<-RUBY
        module Bukkits
          module EngineHelper
            def bar
              'bar'
            end
          end
        end
      RUBY

      @plugin.write "app/helpers/engine_helper.rb", <<-RUBY
        module EngineHelper
          def baz
            'baz'
          end
        end
      RUBY

      add_to_config("config.action_dispatch.show_exceptions = false")

      boot_rails
      require "#{rails_root}/config/environment"

      methods = Bukkits::Engine.helpers.public_instance_methods.collect(&:to_s).sort
      expected = ["bar", "baz"]
      assert_equal expected, methods
    end

    test "setting priority for engines with config.railties_order" do
      @blog = engine "blog" do |plugin|
        plugin.write "lib/blog.rb", <<-RUBY
          module Blog
            class Engine < ::Rails::Engine
            end
          end
        RUBY
      end

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      controller "main", <<-RUBY
        class MainController < ActionController::Base
          def foo
            render :inline => '<%= render :partial => "shared/foo" %>'
          end

          def bar
            render :inline => '<%= render :partial => "shared/bar" %>'
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          match "/foo" => "main#foo"
          match "/bar" => "main#bar"
        end
      RUBY

      @plugin.write "app/views/shared/_foo.html.erb", <<-RUBY
        Bukkit's foo partial
      RUBY

      app_file "app/views/shared/_foo.html.erb", <<-RUBY
        App's foo partial
      RUBY

      @blog.write "app/views/shared/_bar.html.erb", <<-RUBY
        Blog's bar partial
      RUBY

      app_file "app/views/shared/_bar.html.erb", <<-RUBY
        App's bar partial
      RUBY

      @plugin.write "app/assets/javascripts/foo.js", <<-RUBY
        // Bukkit's foo js
      RUBY

      app_file "app/assets/javascripts/foo.js", <<-RUBY
        // App's foo js
      RUBY

      @blog.write "app/assets/javascripts/bar.js", <<-RUBY
        // Blog's bar js
      RUBY

      app_file "app/assets/javascripts/bar.js", <<-RUBY
        // App's bar js
      RUBY

      add_to_config("config.railties_order = [:all, :main_app, Blog::Engine]")

      boot_rails
      require "#{rails_root}/config/environment"

      get("/foo")
      assert_equal "Bukkit's foo partial", last_response.body.strip

      get("/bar")
      assert_equal "App's bar partial", last_response.body.strip

      get("/assets/foo.js")
      assert_equal "// Bukkit's foo js\n;", last_response.body.strip

      get("/assets/bar.js")
      assert_equal "// App's bar js\n;", last_response.body.strip

      # ensure that railties are not added twice
      railties = Rails.application.ordered_railties.map(&:class)
      assert_equal railties, railties.uniq
    end

    test "railties_order adds :all with lowest priority if not given" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      controller "main", <<-RUBY
        class MainController < ActionController::Base
          def foo
            render :inline => '<%= render :partial => "shared/foo" %>'
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          match "/foo" => "main#foo"
        end
      RUBY

      @plugin.write "app/views/shared/_foo.html.erb", <<-RUBY
        Bukkit's foo partial
      RUBY

      app_file "app/views/shared/_foo.html.erb", <<-RUBY
        App's foo partial
      RUBY

      add_to_config("config.railties_order = [Bukkits::Engine]")

      boot_rails
      require "#{rails_root}/config/environment"

      get("/foo")
      assert_equal "Bukkit's foo partial", last_response.body.strip
    end

  private
    def app
      Rails.application
    end
  end
end
