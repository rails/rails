require "isolation/abstract_unit"
require "railties/shared_tests"
require 'stringio'
require 'rack/test'
require 'rack/file'

module RailtiesTest
  class EngineTest < Test::Unit::TestCase

    include ActiveSupport::Testing::Isolation
    include SharedTests
    include Rack::Test::Methods

    def setup
      build_app

      @plugin = engine "bukkits" do |plugin|
        plugin.write "lib/bukkits.rb", <<-RUBY
          class Bukkits
            class Engine < ::Rails::Engine
              railtie_name "bukkits"
            end
          end
        RUBY
        plugin.write "lib/another.rb", "class Another; end"
      end
    end

    test "Rails::Engine itself does not respond to config" do
      boot_rails
      assert !Rails::Engine.respond_to?(:config)
    end

    test "initializers are executed after application configuration initializers" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
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
        class Bukkits
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

    test "it provides routes as default endpoint" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
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
        class Bukkits
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
        class Bukkits
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
        class Bukkits
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
        class Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, 'hello'] }
          end
        end
      RUBY

      boot_rails

      env = Rack::MockRequest.env_for("/")
      Bukkits::Engine.call(env)
      assert_equal Bukkits::Engine.routes, env['action_dispatch.routes']

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_equal Rails.application.routes, env['action_dispatch.routes']
    end

    test "it allows to set asset_path" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY


      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/foo" => "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/foo_controller.rb", <<-RUBY
        class FooController < ActionController::Base
          def index
            render :index
          end
        end
      RUBY

      @plugin.write "app/views/foo/index.html.erb", <<-ERB
        <%= image_path("foo.png") %>
        <%= javascript_include_tag("foo") %>
        <%= stylesheet_link_tag("foo") %>
      ERB

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount Bukkits::Engine => "/bukkits"
        end
      RUBY

      add_to_config 'config.asset_path = "/omg%s"'

      boot_rails

      # should set asset_path with engine name by default
      assert_equal "/bukkits_engine%s", ::Bukkits::Engine.config.asset_path

      ::Bukkits::Engine.config.asset_path = "/bukkits%s"

      get("/bukkits/foo")
      stripped_body = last_response.body.split("\n").map(&:strip).join

      expected =  "/omg/bukkits/images/foo.png" +
                  "<script src=\"/omg/bukkits/javascripts/foo.js\" type=\"text/javascript\"></script>" +
                  "<link href=\"/omg/bukkits/stylesheets/foo.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />"
      assert_equal expected, stripped_body
    end

    test "default application's asset_path" do
      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/foo" => "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/foo_controller.rb", <<-RUBY
        class FooController < ActionController::Base
          def index
            render :inline => '<%= image_path("foo.png") %>'
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          mount Bukkits::Engine => "/bukkits"
        end
      RUBY

      boot_rails

      get("/bukkits/foo")
      assert_equal "/bukkits/images/foo.png", last_response.body.strip
    end

    test "engine's files are served via ActionDispatch::Static" do
      add_to_config "config.serve_static_assets = true"

      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            engine_name :bukkits
          end
        end
      RUBY

      @plugin.write "public/bukkits.html", "/bukkits/bukkits.html"
      app_file "public/app.html", "/app.html"
      app_file "public/bukkits/file_from_app.html", "/bukkits/file_from_app.html"

      boot_rails

      get("/app.html")
      assert_equal File.read(File.join(app_path, "public/app.html")), last_response.body

      get("/bukkits/bukkits.html")
      assert_equal File.read(File.join(@plugin.path, "public/bukkits.html")), last_response.body

      get("/bukkits/file_from_app.html")
      assert_equal File.read(File.join(app_path, "public/bukkits/file_from_app.html")), last_response.body
    end

    test "an applications files are given priority over an engines files when served via ActionDispatch::Static" do
      add_to_config "config.serve_static_assets = true"

      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            engine_name :bukkits
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          mount Bukkits::Engine => "/bukkits"
        end
      RUBY

      @plugin.write "public/bukkits.html", "in engine"

      app_file "public/bukkits/bukkits.html", "in app"

      boot_rails

      get('/bukkits/bukkits.html')

      assert_equal 'in app', last_response.body.strip
    end

    test "shared engine should include application's helpers and own helpers" do
      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match "/foo" => "bukkits/foo#index", :as => "foo"
          match "/foo/show" => "bukkits/foo#show"
          match "/foo/bar" => "bukkits/foo#bar"
        end
      RUBY

      app_file "app/helpers/some_helper.rb", <<-RUBY
        module SomeHelper
          def something
            "Something... Something... Something..."
          end
        end
      RUBY

      @plugin.write "app/helpers/bar_helper.rb", <<-RUBY
        module BarHelper
          def bar
            "It's a bar."
          end
        end
      RUBY

      @plugin.write "app/controllers/bukkits/foo_controller.rb", <<-RUBY
        class Bukkits::FooController < ActionController::Base
          def index
            render :inline => "<%= something %>"
          end

          def show
            render :text => foo_path
          end

          def bar
            render :inline => "<%= bar %>"
          end
        end
      RUBY

      boot_rails

      get("/foo")
      assert_equal "Something... Something... Something...", last_response.body

      get("/foo/show")
      assert_equal "/foo", last_response.body

      get("/foo/bar")
      assert_equal "It's a bar.", last_response.body
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
      assert_equal Bukkits._railtie, Bukkits::Engine
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
      assert_match /name="post\[title\]"/, last_response.body
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
      assert_raise(NoMethodError) do  Bukkits::Engine.config.bukkits_seeds_loaded end

      Bukkits::Engine.load_seed
      assert Bukkits::Engine.config.bukkits_seeds_loaded
    end

    test "using namespace more than once on one module should not overwrite _railtie method" do
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

      assert_equal AppTemplate._railtie, AppTemplate::Engine
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

    test "ensure that engine properly sets assets directories" do
      add_to_config("config.action_dispatch.show_exceptions = false")
      add_to_config("config.serve_static_assets = true")

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      @plugin.write "public/stylesheets/foo.css", ""
      @plugin.write "public/javascripts/foo.js", ""

      @plugin.write "app/views/layouts/bukkits/application.html.erb", <<-RUBY
        <%= stylesheet_link_tag :all %>
        <%= javascript_include_tag :all %>
        <%= yield %>
      RUBY

      @plugin.write "app/controllers/bukkits/home_controller.rb", <<-RUBY
        module Bukkits
          class HomeController < ActionController::Base
            def index
              render :text => "Good morning!", :layout => "bukkits/application"
            end
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/home" => "home#index"
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount Bukkits::Engine => "/bukkits"
        end
      RUBY

      require 'rack/test'
      extend Rack::Test::Methods

      boot_rails

      require "#{rails_root}/config/environment"

      assert_equal File.join(@plugin.path, "public"),             Bukkits::HomeController.assets_dir
      assert_equal File.join(@plugin.path, "public/stylesheets"), Bukkits::HomeController.stylesheets_dir
      assert_equal File.join(@plugin.path, "public/javascripts"), Bukkits::HomeController.javascripts_dir

      assert_equal File.join(app_path, "public"),             ActionController::Base.assets_dir
      assert_equal File.join(app_path, "public/stylesheets"), ActionController::Base.stylesheets_dir
      assert_equal File.join(app_path, "public/javascripts"), ActionController::Base.javascripts_dir

      get "/bukkits/home"

      assert_match %r{bukkits/stylesheets/foo.css}, last_response.body
      assert_match %r{bukkits/javascripts/foo.js}, last_response.body
    end

  private
    def app
      Rails.application
    end
  end
end
