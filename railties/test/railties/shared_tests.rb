module RailtiesTest
  # Holds tests shared between plugin and engines
  module SharedTests
    def boot_rails
      super
      require "#{app_path}/config/environment"
    end

    def app
      @app ||= Rails.application
    end

    def test_plugin_puts_its_lib_directory_on_load_path
      boot_rails
      require "another"
      assert_equal "Another", Another.name
    end

    def test_plugin_paths_get_added_to_as_dependency_list
      boot_rails
      assert_equal "Another", Another.name
    end

    def test_plugins_constants_are_not_reloaded_by_default
      boot_rails
      assert_equal "Another", Another.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/another.rb")
      assert_nothing_raised { Another }
    end

    def test_plugin_constants_get_reloaded_if_config_reload_plugins
      add_to_config <<-RUBY
        config.#{reload_config} = true
      RUBY

      boot_rails

      assert_equal "Another", Another.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/another.rb")
      assert_raises(NameError) { Another }
    end

    def test_plugin_puts_its_models_directory_on_load_path
      @plugin.write "app/models/my_bukkit.rb", "class MyBukkit ; end"
      boot_rails
      assert_nothing_raised { MyBukkit }
    end

    def test_plugin_puts_its_controllers_directory_on_the_load_path
      @plugin.write "app/controllers/bukkit_controller.rb", "class BukkitController ; end"
      boot_rails
      assert_nothing_raised { BukkitController }
    end

    def test_plugin_adds_its_views_to_view_paths
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

    def test_plugin_adds_its_views_to_view_paths_with_lower_proriority
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

    def test_plugin_adds_helpers_to_controller_views
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

    def test_plugin_eager_load_any_path_under_app
      @plugin.write "app/anything/foo.rb", <<-RUBY
        module Foo; end
      RUBY

      boot_rails
      assert Foo
    end

    def test_routes_are_added_to_router
      @plugin.write "config/routes.rb", <<-RUBY
        class Sprokkit
          def self.call(env)
            [200, {'Content-Type' => 'text/html'}, ["I am a Sprokkit"]]
          end
        end

        Rails.application.routes.draw do
          match "/sprokkit", :to => Sprokkit
        end
      RUBY

      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods

      get "/sprokkit"
      assert_equal "I am a Sprokkit", last_response.body
    end

    def test_routes_in_plugins_have_lower_priority_than_application_ones
      controller "foo", <<-RUBY
        class FooController < ActionController::Base
          def index
            render :text => "foo"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do |map|
          match 'foo', :to => 'foo#index'
        end
      RUBY

      @plugin.write "app/controllers/bar_controller.rb", <<-RUBY
        class BarController < ActionController::Base
          def index
            render :text => "bar"
          end
        end
      RUBY

      @plugin.write "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do |map|
          match 'foo', :to => 'bar#index'
          match 'bar', :to => 'bar#index'
        end
      RUBY

      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods

      get '/foo'
      assert_equal 'foo', last_response.body

      get '/bar'
      assert_equal 'bar', last_response.body
    end

    def test_rake_tasks_lib_tasks_are_loaded
      $executed = false
      @plugin.write "lib/tasks/foo.rake", <<-RUBY
        task :foo do
          $executed = true
        end
      RUBY

      boot_rails
      require 'rake'
      require 'rake/rdoctask'
      require 'rake/testtask'
      Rails.application.load_tasks
      Rake::Task[:foo].invoke
      assert $executed
    end

    def test_i18n_files_have_lower_priority_than_application_ones
      add_to_config <<-RUBY
        config.i18n.load_path << "#{app_path}/app/locales/en.yml"
      RUBY

      app_file 'app/locales/en.yml', <<-YAML
en:
  bar: "1"
YAML

      app_file 'config/locales/en.yml', <<-YAML
en:
  foo: "2"
  bar: "2"
YAML

      @plugin.write 'config/locales/en.yml', <<-YAML
en:
  foo: "3"
YAML

      boot_rails

      assert_equal %W(
        #{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activemodel/lib/active_model/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activerecord/lib/active_record/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/actionpack/lib/action_view/locale/en.yml
        #{@plugin.path}/config/locales/en.yml
        #{app_path}/config/locales/en.yml
        #{app_path}/app/locales/en.yml
      ).map { |path| File.expand_path(path) }, I18n.load_path.map { |path| File.expand_path(path) }

      assert_equal "2", I18n.t(:foo)
      assert_equal "1", I18n.t(:bar)
    end

    def test_plugin_metals_added_to_middleware_stack
      @plugin.write 'app/metal/foo_metal.rb', <<-RUBY
        class FooMetal
          def self.call(env)
            [200, { "Content-Type" => "text/html"}, ["FooMetal"]]
          end
        end
      RUBY

      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods

      get "/not/slash"
      assert_equal 200, last_response.status
      assert_equal "FooMetal", last_response.body
    end

    def test_namespaced_controllers_with_namespaced_routes
      @plugin.write "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          namespace :admin do
            namespace :foo do
              match "bar", :to => "bar#index"
            end
          end
        end
      RUBY

      @plugin.write "app/controllers/admin/foo/bar_controller.rb", <<-RUBY
        class Admin::Foo::BarController < ApplicationController
          def index
            render :text => "Rendered from namespace"
          end
        end
      RUBY

      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods

      get "/admin/foo/bar"
      assert_equal 200, last_response.status
      assert_equal "Rendered from namespace", last_response.body
    end

    def test_plugin_initializers
      $plugin_initializer = false
      @plugin.write "config/initializers/foo.rb", <<-RUBY
        $plugin_initializer = true
      RUBY

      boot_rails
      assert $plugin_initializer
    end

    def test_plugin_midleware_referenced_in_configuration
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

      add_to_config "config.middleware.use \"Bukkits\""
      boot_rails
    end
  end
end
