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

    def test_serving_sprockets_assets
      @plugin.write "app/assets/javascripts/engine.js.erb", "<%= :alert %>();"

      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods

      get "/assets/engine.js"
      assert_match "alert()", last_response.body
    end

    def test_copying_migrations
      @plugin.write "db/migrate/1_create_users.rb", <<-RUBY
        class CreateUsers < ActiveRecord::Migration
        end
      RUBY

      @plugin.write "db/migrate/2_add_last_name_to_users.rb", <<-RUBY
        class AddLastNameToUsers < ActiveRecord::Migration
        end
      RUBY

      @plugin.write "db/migrate/3_create_sessions.rb", <<-RUBY
        class CreateSessions < ActiveRecord::Migration
        end
      RUBY

      app_file "db/migrate/1_create_sessions.rb", <<-RUBY
        class CreateSessions < ActiveRecord::Migration
        end
      RUBY

      yaffle = plugin "acts_as_yaffle", "::LEVEL = config.log_level" do |plugin|
        plugin.write "lib/acts_as_yaffle.rb", "class ActsAsYaffle; end"
      end

      yaffle.write "db/migrate/1_create_yaffles.rb", <<-RUBY
        class CreateYaffles < ActiveRecord::Migration
        end
      RUBY

      add_to_config "ActiveRecord::Base.timestamped_migrations = false"

      boot_rails
      railties = Rails.application.railties.all.map(&:railtie_name)

      Dir.chdir(app_path) do
        output = `bundle exec rake bukkits:install:migrations`

        assert File.exists?("#{app_path}/db/migrate/2_create_users.rb")
        assert File.exists?("#{app_path}/db/migrate/3_add_last_name_to_users.rb")
        assert_match(/Copied migration 2_create_users.rb from bukkits/, output)
        assert_match(/Copied migration 3_add_last_name_to_users.rb from bukkits/, output)
        assert_match(/NOTE: Migration 3_create_sessions.rb from bukkits has been skipped/, output)
        assert_equal 3, Dir["#{app_path}/db/migrate/*.rb"].length

        output = `bundle exec rake railties:install:migrations`.split("\n")

        assert File.exists?("#{app_path}/db/migrate/4_create_yaffles.rb")
        assert_no_match(/2_create_users/, output.join("\n"))

        yaffle_migration_order = output.index(output.detect{|o| /Copied migration 4_create_yaffles.rb from acts_as_yaffle/ =~ o })
        bukkits_migration_order = output.index(output.detect{|o| /NOTE: Migration 3_create_sessions.rb from bukkits has been skipped/ =~ o })
        assert_not_nil yaffle_migration_order, "Expected migration to be copied"
        assert_not_nil bukkits_migration_order, "Expected migration to be skipped"
        assert_equal(railties.index('acts_as_yaffle') > railties.index('bukkits'), yaffle_migration_order > bukkits_migration_order)

        migrations_count = Dir["#{app_path}/db/migrate/*.rb"].length
        output = `bundle exec rake railties:install:migrations`

        assert_equal migrations_count, Dir["#{app_path}/db/migrate/*.rb"].length
      end
    end

    def test_no_rake_task_without_migrations
      boot_rails
      require 'rake'
      require 'rdoc/task'
      require 'rake/testtask'
      Rails.application.load_tasks
      assert !Rake::Task.task_defined?('bukkits:install:migrations')
    end

    def test_puts_its_lib_directory_on_load_path
      boot_rails
      require "another"
      assert_equal "Another", Another.name
    end

    def test_puts_its_models_directory_on_autoload_path
      @plugin.write "app/models/my_bukkit.rb", "class MyBukkit ; end"
      boot_rails
      assert_nothing_raised { MyBukkit }
    end

    def test_puts_its_controllers_directory_on_autoload_path
      @plugin.write "app/controllers/bukkit_controller.rb", "class BukkitController ; end"
      boot_rails
      assert_nothing_raised { BukkitController }
    end

    def test_adds_its_views_to_view_paths
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

    def test_adds_its_views_to_view_paths_with_lower_proriority_than_app_ones
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

    def test_adds_helpers_to_controller_views
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

    def test_autoload_any_path_under_app
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
        AppTemplate::Application.routes.draw do
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
        Rails.application.routes.draw do
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
      require 'rdoc/task'
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

      expected_locales = %W(
        #{RAILS_FRAMEWORK_ROOT}/activesupport/lib/active_support/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activemodel/lib/active_model/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/activerecord/lib/active_record/locale/en.yml
        #{RAILS_FRAMEWORK_ROOT}/actionpack/lib/action_view/locale/en.yml
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

    def test_initializers
      $plugin_initializer = false
      @plugin.write "config/initializers/foo.rb", <<-RUBY
        $plugin_initializer = true
      RUBY

      boot_rails
      assert $plugin_initializer
    end

    def test_midleware_referenced_in_configuration
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
