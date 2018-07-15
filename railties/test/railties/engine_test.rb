# frozen_string_literal: true

require "isolation/abstract_unit"
require "stringio"
require "rack/test"

module RailtiesTest
  class EngineTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
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

    def boot_rails
      require "#{app_path}/config/environment"
    end

    def migrations
      migration_root = File.expand_path(ActiveRecord::Migrator.migrations_paths.first, app_path)
      ActiveRecord::MigrationContext.new(migration_root).migrations
    end

    test "serving sprocket's assets" do
      @plugin.write "app/assets/javascripts/engine.js.erb", "<%= :alert %>();"
      add_to_env_config "development", "config.assets.digest = false"

      boot_rails

      get "/assets/engine.js"
      assert_match "alert()", last_response.body
    end

    test "rake environment can be called in the engine" do
      boot_rails

      @plugin.write "Rakefile", <<-RUBY
        APP_RAKEFILE = '#{app_path}/Rakefile'
        load 'rails/tasks/engine.rake'
        task :foo => :environment do
          puts "Task ran"
        end
      RUBY

      Dir.chdir(@plugin.path) do
        output = `bundle exec rake foo`
        assert_match "Task ran", output
      end
    end

    test "copying migrations" do
      @plugin.write "db/migrate/1_create_users.rb", <<-RUBY
        class CreateUsers < ActiveRecord::Migration::Current
        end
      RUBY

      @plugin.write "db/migrate/2_add_last_name_to_users.rb", <<-RUBY
        class AddLastNameToUsers < ActiveRecord::Migration::Current
        end
      RUBY

      @plugin.write "db/migrate/3_create_sessions.rb", <<-RUBY
        class CreateSessions < ActiveRecord::Migration::Current
        end
      RUBY

      app_file "db/migrate/1_create_sessions.rb", <<-RUBY
        class CreateSessions < ActiveRecord::Migration::Current
          def up
          end
        end
      RUBY

      boot_rails

      Dir.chdir(app_path) do
        # Install Active Storage migration file first so as not to affect test.
        `bundle exec rake active_storage:install`
        output = `bundle exec rake bukkits:install:migrations`

        ["CreateUsers", "AddLastNameToUsers", "CreateSessions"].each do |migration_name|
          assert migrations.detect { |migration| migration.name == migration_name }
        end
        assert_match(/Copied migration \d+_create_users\.bukkits\.rb from bukkits/, output)
        assert_match(/Copied migration \d+_add_last_name_to_users\.bukkits\.rb from bukkits/, output)
        assert_match(/NOTE: Migration \d+_create_sessions\.rb from bukkits has been skipped/, output)

        migrations_count = Dir["#{app_path}/db/migrate/*.rb"].length

        assert_equal migrations.length, migrations_count

        output = `bundle exec rake railties:install:migrations`.split("\n")

        assert_equal migrations_count, Dir["#{app_path}/db/migrate/*.rb"].length

        assert_no_match(/\d+_create_users/, output.join("\n"))

        bukkits_migration_order = output.index(output.detect { |o| /NOTE: Migration \d+_create_sessions\.rb from bukkits has been skipped/ =~ o })
        assert_not_nil bukkits_migration_order, "Expected migration to be skipped"
      end
    end

    test "respects the order of railties when installing migrations" do
      @blog = engine "blog" do |plugin|
        plugin.write "lib/blog.rb", <<-RUBY
          module Blog
            class Engine < ::Rails::Engine
            end
          end
        RUBY
      end

      @plugin.write "db/migrate/1_create_users.rb", <<-RUBY
        class CreateUsers < ActiveRecord::Migration::Current
        end
      RUBY

      @blog.write "db/migrate/2_create_blogs.rb", <<-RUBY
        class CreateBlogs < ActiveRecord::Migration::Current
        end
      RUBY

      add_to_config("config.railties_order = [Bukkits::Engine, Blog::Engine, :all, :main_app]")

      boot_rails

      Dir.chdir(app_path) do
        output = `bundle exec rake railties:install:migrations`.split("\n")

        assert_match(/Copied migration \d+_create_users\.bukkits\.rb from bukkits/, output.first)
        assert_match(/Copied migration \d+_create_blogs\.blog_engine\.rb from blog_engine/, output.second)
      end
    end

    test "dont reverse default railties order" do
      @api = engine "api" do |plugin|
        plugin.write "lib/api.rb", <<-RUBY
          module Api
            class Engine < ::Rails::Engine; end
          end
        RUBY
      end

      # added last but here is loaded before api engine
      @core = engine "core" do |plugin|
        plugin.write "lib/core.rb", <<-RUBY
          module Core
            class Engine < ::Rails::Engine; end
          end
        RUBY
      end

      @core.write "db/migrate/1_create_users.rb", <<-RUBY
        class CreateUsers < ActiveRecord::Migration::Current; end
      RUBY

      @api.write "db/migrate/2_create_keys.rb", <<-RUBY
        class CreateKeys < ActiveRecord::Migration::Current; end
      RUBY

      boot_rails

      Dir.chdir(app_path) do
        # Install Active Storage migration file first so as not to affect test.
        `bundle exec rake active_storage:install`
        output = `bundle exec rake railties:install:migrations`.split("\n")

        assert_match(/Copied migration \d+_create_users\.core_engine\.rb from core_engine/, output.first)
        assert_match(/Copied migration \d+_create_keys\.api_engine\.rb from api_engine/, output.second)
      end
    end

    test "mountable engine should copy migrations within engine_path" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      @plugin.write "db/migrate/0_add_first_name_to_users.rb", <<-RUBY
        class AddFirstNameToUsers < ActiveRecord::Migration::Current
        end
      RUBY

      @plugin.write "Rakefile", <<-RUBY
        APP_RAKEFILE = '#{app_path}/Rakefile'
        load 'rails/tasks/engine.rake'
      RUBY

      add_to_config "ActiveRecord::Base.timestamped_migrations = false"

      boot_rails

      Dir.chdir(@plugin.path) do
        output = `bundle exec rake app:bukkits:install:migrations`

        migration_with_engine_path = migrations.detect { |migration| migration.name == "AddFirstNameToUsers" }
        assert migration_with_engine_path
        assert_match(/\/db\/migrate\/\d+_add_first_name_to_users\.bukkits\.rb/, migration_with_engine_path.filename)
        assert_match(/Copied migration \d+_add_first_name_to_users\.bukkits\.rb from bukkits/, output)
        assert_equal migrations.length, Dir["#{app_path}/db/migrate/*.rb"].length
      end
    end

    test "no rake task without migrations" do
      boot_rails
      require "rake"
      require "rdoc/task"
      require "rake/testtask"
      Rails.application.load_tasks
      assert_not Rake::Task.task_defined?("bukkits:install:migrations")
    end

    test "puts its lib directory on load path" do
      boot_rails
      require "another"
      assert_equal "Another", Another.name
    end

    test "puts its models directory on autoload path" do
      @plugin.write "app/models/my_bukkit.rb", "class MyBukkit ; end"
      boot_rails
      assert_nothing_raised { MyBukkit }
    end

    test "puts its controllers directory on autoload path" do
      @plugin.write "app/controllers/bukkit_controller.rb", "class BukkitController ; end"
      boot_rails
      assert_nothing_raised { BukkitController }
    end

    test "adds its views to view paths" do
      @plugin.write "app/controllers/bukkit_controller.rb", <<-RUBY
        class BukkitController < ActionController::Base
          def index
          end
        end
      RUBY

      @plugin.write "app/views/bukkit/index.html.erb", "Hello bukkits"

      boot_rails

      require "action_controller"
      require "rack/mock"
      response = BukkitController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal "Hello bukkits\n", response[2].body
    end

    test "adds its views to view paths with lower priority than app ones" do
      @plugin.write "app/controllers/bukkit_controller.rb", <<-RUBY
        class BukkitController < ActionController::Base
          def index
          end
        end
      RUBY

      @plugin.write "app/views/bukkit/index.html.erb", "Hello bukkits"
      app_file "app/views/bukkit/index.html.erb", "Hi bukkits"

      boot_rails

      require "action_controller"
      require "rack/mock"
      response = BukkitController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal "Hi bukkits\n", response[2].body
    end

    test "adds helpers to controller views" do
      @plugin.write "app/controllers/bukkit_controller.rb", <<-RUBY
        class BukkitController < ActionController::Base
          def index
          end
        end
      RUBY

      @plugin.write "app/helpers/bukkit_helper.rb", <<-RUBY
        module BukkitHelper
          def bukkits
            "bukkits"
          end
        end
      RUBY

      @plugin.write "app/views/bukkit/index.html.erb", "Hello <%= bukkits %>"

      boot_rails

      require "rack/mock"
      response = BukkitController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal "Hello bukkits\n", response[2].body
    end

    test "autoload any path under app" do
      @plugin.write "app/anything/foo.rb", <<-RUBY
        module Foo; end
      RUBY
      boot_rails
      assert Foo
    end

    test "routes are added to router" do
      @plugin.write "config/routes.rb", <<-RUBY
        class Sprokkit
          def self.call(env)
            [200, {'Content-Type' => 'text/html'}, ["I am a Sprokkit"]]
          end
        end

        Rails.application.routes.draw do
          get "/sprokkit", :to => Sprokkit
        end
      RUBY

      boot_rails

      get "/sprokkit"
      assert_equal "I am a Sprokkit", last_response.body
    end

    test "routes in engines have lower priority than application ones" do
      controller "foo", <<-RUBY
        class FooController < ActionController::Base
          def index
            render plain: "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', :to => 'foo#index'
        end
      RUBY

      @plugin.write "app/controllers/bar_controller.rb", <<-RUBY
        class BarController < ActionController::Base
          def index
            render plain: "bar"
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get 'foo', to: 'bar#index'
          get 'bar', to: 'bar#index'
        end
      RUBY

      boot_rails

      get "/foo"
      assert_equal "foo", last_response.body

      get "/bar"
      assert_equal "bar", last_response.body
    end

    test "rake tasks lib tasks are loaded" do
      $executed = false
      @plugin.write "lib/tasks/foo.rake", <<-RUBY
        task :foo do
          $executed = true
        end
      RUBY

      boot_rails
      require "rake"
      require "rdoc/task"
      require "rake/testtask"
      Rails.application.load_tasks
      Rake::Task[:foo].invoke
      assert $executed
    end

    test "i18n files have lower priority than application ones" do
      add_to_config <<-RUBY
        config.i18n.load_path << "#{app_path}/app/locales/en.yml"
      RUBY

      app_file "app/locales/en.yml", <<-YAML
en:
  bar: "1"
YAML

      app_file "config/locales/en.yml", <<-YAML
en:
  foo: "2"
  bar: "2"
YAML

      @plugin.write "config/locales/en.yml", <<-YAML
en:
  foo: "3"
YAML

      boot_rails

      expected_locales = %W(
        #{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activemodel/lib/active_model/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activerecord/lib/active_record/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/actionview/lib/action_view/locale/en.yml
        #{@plugin.path}/config/locales/en.yml
        #{app_path}/config/locales/en.yml
        #{app_path}/app/locales/en.yml
      ).map { |path| File.expand_path(path) }

      actual_locales = I18n.load_path.map { |path|
        File.expand_path(path)
      } & expected_locales # remove locales external to Rails

      assert_equal expected_locales, actual_locales

      assert_equal "2", I18n.t(:foo)
      assert_equal "1", I18n.t(:bar)
    end

    test "namespaced controllers with namespaced routes" do
      @plugin.write "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          namespace :admin do
            namespace :foo do
              get "bar", to: "bar#index"
            end
          end
        end
      RUBY

      @plugin.write "app/controllers/admin/foo/bar_controller.rb", <<-RUBY
        class Admin::Foo::BarController < ApplicationController
          def index
            render plain: "Rendered from namespace"
          end
        end
      RUBY

      boot_rails

      get "/admin/foo/bar"
      assert_equal 200, last_response.status
      assert_equal "Rendered from namespace", last_response.body
    end

    test "initializers" do
      $plugin_initializer = false
      @plugin.write "config/initializers/foo.rb", <<-RUBY
        $plugin_initializer = true
      RUBY

      boot_rails
      assert $plugin_initializer
    end

    test "middleware referenced in configuration" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          def initialize(app)
            @app = app
          end

          def call(env)
            @app.call(env)
          end
        end
      RUBY

      add_to_config "config.middleware.use Bukkits"
      boot_rails
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
      dummy_index  = initializers.index  { |i| i.name == "dummy_initializer" }
      config_index = initializers.rindex { |i| i.name == :load_config_initializers }
      stack_index  = initializers.index  { |i| i.name == :build_middleware_stack }

      assert config_index < dummy_index
      assert dummy_index < stack_index
    end

    class Upcaser
      def initialize(app)
        @app = app
      end

      def call(env)
        response = @app.call(env)
        response[2] = response[2].collect(&:upcase)
        response
      end
    end

    test "engine is a rack app and can have its own middleware stack" do
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
        Rails.application.routes.draw do
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
            render plain: params[:username]
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          root to: "foo#index"
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
          get "/foo" => lambda { |env| [200, {'Content-Type' => 'text/html'}, ['foo']] }
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

    test "it loads its environments file" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            config.paths["config/environments"].push "config/environments/additional.rb"
          end
        end
      RUBY

      @plugin.write "config/environments/development.rb", <<-RUBY
        Bukkits::Engine.configure do
          config.environment_loaded = true
        end
      RUBY

      @plugin.write "config/environments/additional.rb", <<-RUBY
        Bukkits::Engine.configure do
          config.additional_environment_loaded = true
        end
      RUBY

      boot_rails

      assert Bukkits::Engine.config.environment_loaded
      assert Bukkits::Engine.config.additional_environment_loaded
    end

    test "it passes router in env" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, ['hello']] }
          end
        end
      RUBY

      require "rack/file"
      boot_rails

      env = Rack::MockRequest.env_for("/")
      Bukkits::Engine.call(env)
      assert_equal Bukkits::Engine.routes, env["action_dispatch.routes"]

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_equal Rails.application.routes, env["action_dispatch.routes"]
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
            include ActiveModel::Model

            def to_param
              "1"
            end

            def persisted?
              true
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/bar" => "bar#index", as: "bar"
          mount Bukkits::Engine => "/bukkits", as: "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          get "/foo" => "foo#index", as: "foo"
          get "/foo/show" => "foo#show"
          get "/from_app" => "foo#from_app"
          get "/routes_helpers_in_view" => "foo#routes_helpers_in_view"
          get "/polymorphic_path_without_namespace" => "foo#polymorphic_path_without_namespace"
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
            render inline: "<%= help_the_engine %>"
          end

          def show
            render plain: foo_path
          end

          def from_app
            render inline: "<%= (self.respond_to?(:bar_path) || self.respond_to?(:something)) %>"
          end

          def routes_helpers_in_view
            render inline: "<%= foo_path %>, <%= main_app.bar_path %>"
          end

          def polymorphic_path_without_namespace
            render plain: polymorphic_path(Post.new)
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
      assert ::Bukkits::MyMailer.method_defined?(:foo_url)
      assert_not ::Bukkits::MyMailer.method_defined?(:bar_url)

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
            include ActiveModel::Model
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
        Rails.application.routes.draw do
          mount Bukkits::Engine => "/bukkits", as: "bukkits"
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
        Rails.application.routes.draw do
          mount Bukkits::Awesome::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Awesome::Engine.routes.draw do
          get "/foo" => "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/bukkits/awesome/foo_controller.rb", <<-RUBY
        class Bukkits::Awesome::FooController < ActionController::Base
          def index
            render plain: "ok"
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

    test "wrapping seeding in transaction with helpful output" do
      original_stderr = $stderr

      buffer = StringIO.new
      $stderr = buffer

      @plugin.write "db/seeds.rb", <<-RUBY
        unless ActiveRecord::Base.connection.transaction_open?
          raise "Not in transaction"
        end
        Bukkits::Engine.config.bukkits_seeds_loaded = true
        raise "Bukkits seed error"
      RUBY

      app_file "db/seeds.rb", <<-RUBY
        unless ActiveRecord::Base.connection.transaction_open?
          raise "Not in transaction"
        end
        Rails.application.config.app_seeds_loaded = true
        raise "Rails.application seed error"
      RUBY

      boot_rails

      rails_app_error = assert_raise(RuntimeError) { Rails.application.load_seed }
      assert_equal "Rails.application seed error", rails_app_error.message

      bukkits_error = assert_raise(RuntimeError) { Bukkits::Engine.load_seed }
      assert_equal "Bukkits seed error", bukkits_error.message

      buffer.rewind
      output = buffer.read

      assert_includes output, "An exception was raised while loading"
      assert_includes output, "app/db/seeds.rb"
      assert_includes output, "bukkits/db/seeds.rb"
      assert_includes output, "All database changes have been rolled back. You can safely rerun your seeds when you have fixed the error."

      $stderr = original_stderr
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

      engine "loaded_first" do |plugin|
        plugin.write "lib/loaded_first.rb", <<-RUBY
          module AppTemplate
            module LoadedFirst
              class Engine < ::Rails::Engine
                isolate_namespace(AppTemplate)
              end
            end
          end
        RUBY
      end

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do end
      RUBY

      boot_rails

      assert_equal AppTemplate::LoadedFirst::Engine, AppTemplate.railtie_namespace
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
              g.orm             :data_mapper
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

      app_generators = Rails.application.config.generators.options[:rails]
      assert_equal :mongoid, app_generators[:orm]
      assert_equal :liquid, app_generators[:template_engine]
      assert_equal :test_unit, app_generators[:test_framework]

      generators = Bukkits::Engine.config.generators.options[:rails]
      assert_equal :data_mapper, generators[:orm]
      assert_equal :haml, generators[:template_engine]
      assert_equal :rspec, generators[:test_framework]
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

      generators = Bukkits::Engine.config.generators.options[:rails]
      assert_equal :active_record, generators[:orm]
      assert_equal :rspec, generators[:test_framework]

      app_generators = Rails.application.config.generators.options[:rails]
      assert_equal :test_unit, app_generators[:test_framework]
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

      assert_equal Bukkits::Engine.instance, Rails::Engine.find(@plugin.path)

      # check expanding paths
      engine_dir = @plugin.path.chomp("/").split("/").last
      engine_path = File.join(@plugin.path, "..", engine_dir)
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

      assert_equal [:bar, :baz], Bukkits::Engine.helpers.public_instance_methods.sort
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
            render inline: '<%= render :partial => "shared/foo" %>'
          end

          def bar
            render inline: '<%= render :partial => "shared/bar" %>'
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/foo" => "main#foo"
          get "/bar" => "main#bar"
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
      add_to_env_config "development", "config.assets.digest = false"

      boot_rails

      get("/foo")
      assert_equal "Bukkit's foo partial", last_response.body.strip

      get("/bar")
      assert_equal "App's bar partial", last_response.body.strip

      get("/assets/foo.js")
      assert_match "// Bukkit's foo js", last_response.body.strip

      get("/assets/bar.js")
      assert_match "// App's bar js", last_response.body.strip

      # ensure that railties are not added twice
      railties = Rails.application.send(:ordered_railties).map(&:class)
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
            render inline: '<%= render :partial => "shared/foo" %>'
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/foo" => "main#foo"
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

      get("/foo")
      assert_equal "Bukkit's foo partial", last_response.body.strip
    end

    test "engine can be properly mounted at root" do
      add_to_config("config.action_dispatch.show_exceptions = false")
      add_to_config("config.public_file_server.enabled = false")

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace ::Bukkits
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          root "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/bukkits/foo_controller.rb", <<-RUBY
        module Bukkits
          class FooController < ActionController::Base
            def index
              text = <<-TEXT
                script_name: \#{request.script_name}
                fullpath: \#{request.fullpath}
                path: \#{request.path}
              TEXT
              render plain: text
            end
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          mount Bukkits::Engine => "/"
        end
      RUBY

      boot_rails

      expected = <<-TEXT
        script_name:
        fullpath: /
        path: /
      TEXT

      get("/")
      assert_equal expected.split("\n").map(&:strip),
                   last_response.body.split("\n").map(&:strip)
    end

    test "paths are properly generated when application is mounted at sub-path" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      app_file "app/controllers/bar_controller.rb", <<-RUBY
        class BarController < ApplicationController
          def index
            render plain: bukkits.bukkit_path
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/bar' => 'bar#index', :as => 'bar'
          mount Bukkits::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          get '/bukkit' => 'bukkit#index'
        end
      RUBY

      @plugin.write "app/controllers/bukkits/bukkit_controller.rb", <<-RUBY
        class Bukkits::BukkitController < ActionController::Base
          def index
            render plain: main_app.bar_path
          end
        end
      RUBY

      boot_rails

      get("/bukkits/bukkit", {}, { "SCRIPT_NAME" => "/foo" })
      assert_equal "/foo/bar", last_response.body

      get("/bar", {}, { "SCRIPT_NAME" => "/foo" })
      assert_equal "/foo/bukkits/bukkit", last_response.body
    end

    test "paths are properly generated when application is mounted at sub-path and relative_url_root is set" do
      add_to_config "config.relative_url_root = '/foo'"

      @plugin.write "lib/bukkits.rb", <<-RUBY
        module Bukkits
          class Engine < ::Rails::Engine
            isolate_namespace Bukkits
          end
        end
      RUBY

      app_file "app/controllers/bar_controller.rb", <<-RUBY
        class BarController < ApplicationController
          def index
            render plain: bukkits.bukkit_path
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/bar' => 'bar#index', :as => 'bar'
          mount Bukkits::Engine => "/bukkits", :as => "bukkits"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          get '/bukkit' => 'bukkit#index'
        end
      RUBY

      @plugin.write "app/controllers/bukkits/bukkit_controller.rb", <<-RUBY
        class Bukkits::BukkitController < ActionController::Base
          def index
            render plain: main_app.bar_path
          end
        end
      RUBY

      boot_rails

      get("/bukkits/bukkit", {}, { "SCRIPT_NAME" => "/foo" })
      assert_equal "/foo/bar", last_response.body

      get("/bar", {}, { "SCRIPT_NAME" => "/foo" })
      assert_equal "/foo/bukkits/bukkit", last_response.body
    end

    test "isolated engine can be mounted under multiple static locations" do
      app_file "app/controllers/foos_controller.rb", <<-RUBY
        class FoosController < ApplicationController
          def through_fruits
            render plain: fruit_bukkits.posts_path
          end

          def through_vegetables
            render plain: vegetable_bukkits.posts_path
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          scope "/fruits" do
            mount Bukkits::Engine => "/bukkits", as: :fruit_bukkits
          end

          scope "/vegetables" do
            mount Bukkits::Engine => "/bukkits", as: :vegetable_bukkits
          end

          get "/through_fruits" => "foos#through_fruits"
          get "/through_vegetables" => "foos#through_vegetables"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          resources :posts, only: :index
        end
      RUBY

      boot_rails

      get("/through_fruits")
      assert_equal "/fruits/bukkits/posts", last_response.body

      get("/through_vegetables")
      assert_equal "/vegetables/bukkits/posts", last_response.body
    end

    test "isolated engine can be mounted under multiple dynamic locations" do
      app_file "app/controllers/foos_controller.rb", <<-RUBY
        class FoosController < ApplicationController
          def through_fruits
            render plain: fruit_bukkits.posts_path(fruit_id: 1)
          end

          def through_vegetables
            render plain: vegetable_bukkits.posts_path(vegetable_id: 1)
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          resources :fruits do
            mount Bukkits::Engine => "/bukkits"
          end

          resources :vegetables do
            mount Bukkits::Engine => "/bukkits"
          end

          get "/through_fruits" => "foos#through_fruits"
          get "/through_vegetables" => "foos#through_vegetables"
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          resources :posts, only: :index
        end
      RUBY

      boot_rails

      get("/through_fruits")
      assert_equal "/fruits/1/bukkits/posts", last_response.body

      get("/through_vegetables")
      assert_equal "/vegetables/1/bukkits/posts", last_response.body
    end

    test "route helpers resolve script name correctly when called with different script name from current one" do
      @plugin.write "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index
            render plain: fruit_bukkits.posts_path(fruit_id: 2)
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          resources :fruits do
            mount Bukkits::Engine => "/bukkits"
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          resources :posts, only: :index
        end
      RUBY

      boot_rails

      get("/fruits/1/bukkits/posts")
      assert_equal "/fruits/2/bukkits/posts", last_response.body
    end

    test "active_storage:install task works within engine" do
      @plugin.write "Rakefile", <<-RUBY
        APP_RAKEFILE = '#{app_path}/Rakefile'
        load 'rails/tasks/engine.rake'
      RUBY

      Dir.chdir(@plugin.path) do
        output = `bundle exec rake app:active_storage:install`
        assert $?.success?, output

        active_storage_migration = migrations.detect { |migration| migration.name == "CreateActiveStorageTables" }
        assert active_storage_migration
      end
    end

  private
    def app
      Rails.application
    end
  end
end
