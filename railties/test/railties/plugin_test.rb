require "isolation/abstract_unit"

module RailtiesTest
  class PluginTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app

      @plugin = plugin "bukkits", "::LEVEL = config.log_level" do |plugin|
        plugin.write "lib/bukkits.rb", "class Bukkits; end"
      end
    end

    def boot_rails
      super
      require "#{app_path}/config/environment"
    end

    def app
      @app ||= Rails.application
    end

    test "it loads the plugin's init.rb file" do
      boot_rails
      assert_equal "loaded", BUKKITS
    end

    test "the init.rb file has access to the config object" do
      boot_rails
      assert_equal :debug, LEVEL
    end

    test "the plugin puts its lib directory on the load path" do
      boot_rails
      require "bukkits"
      assert_equal "Bukkits", Bukkits.name
    end

    test "plugin init is ran before application initializers" do
      plugin "foo", "$foo = true" do |plugin|
        plugin.write "lib/foo.rb", "module Foo; end"
      end

      app_file 'config/initializers/foo.rb', <<-RUBY
        raise "no $foo" unless $foo
        raise "no Foo" unless Foo
      RUBY

      boot_rails
      assert $foo
    end

    test "plugin paths get added to the AS::Dependency list" do
      boot_rails
      assert_equal "Bukkits", Bukkits.name
    end

    test "plugin constants do not get reloaded by default" do
      boot_rails
      assert_equal "Bukkits", Bukkits.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/bukkits.rb")
      assert_nothing_raised { Bukkits }
    end

    test "plugin constants get reloaded if config.reload_plugins is set" do
      add_to_config <<-RUBY
        config.reload_plugins = true
      RUBY

      boot_rails

      assert_equal "Bukkits", Bukkits.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/bukkits.rb")
      assert_raises(NameError) { Bukkits }
    end

    test "plugin should work without init.rb" do
      @plugin.delete("init.rb")

      boot_rails

      require "bukkits"
      assert_nothing_raised { Bukkits }
    end

    test "the plugin puts its models directory on the load path" do
      @plugin.write "app/models/my_bukkit.rb", "class MyBukkit ; end"

      boot_rails

      assert_nothing_raised { MyBukkit }
    end

    test "the plugin puts is controllers directory on the load path" do
      @plugin.write "app/controllers/bukkit_controller.rb", "class BukkitController ; end"

      boot_rails

      assert_nothing_raised { BukkitController }
    end

    test "the plugin adds its view to the load path" do
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

    test "the plugin adds helpers to the controller's views" do
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

    test "routes.rb are added to the router" do
      @plugin.write "config/routes.rb", <<-RUBY
        class Sprokkit
          def self.call(env)
            [200, {'Content-Type' => 'text/html'}, ["I am a Sprokkit"]]
          end
        end

        ActionController::Routing::Routes.draw do
          match "/sprokkit", :to => Sprokkit
        end
      RUBY

      boot_rails
      require "rack/mock"
      response = Rails.application.call(Rack::MockRequest.env_for("/sprokkit"))
      assert_equal "I am a Sprokkit", response[2].join
    end

    test "tasks are loaded by default" do
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

    test "deprecated tasks are also loaded" do
      $executed = false
      @plugin.write "tasks/foo.rake", <<-RUBY
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

    test "i18n files are added with lower priority than application ones" do
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
        #{app_path}/vendor/plugins/bukkits/config/locales/en.yml
        #{app_path}/config/locales/en.yml
        #{app_path}/app/locales/en.yml
      ).map { |path| File.expand_path(path) }, I18n.load_path.map { |path| File.expand_path(path) }

      assert_equal "2", I18n.t(:foo)
      assert_equal "1", I18n.t(:bar)
    end

    test "plugin metals are added to the middleware stack" do
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

      get "/"
      assert_equal 200, last_response.status
      assert_equal "FooMetal", last_response.body
    end

    test "namespaced controllers with namespaced routes" do
      @plugin.write "config/routes.rb", <<-RUBY
        ActionController::Routing::Routes.draw do
          namespace :admin do
            match "index", :to => "admin/foo#index"
          end
        end
      RUBY

      @plugin.write "app/controllers/admin/foo_controller.rb", <<-RUBY
        class Admin::FooController < ApplicationController
          def index
            render :text => "Rendered from namespace"
          end
        end
      RUBY

      boot_rails

      require 'rack/test'
      extend Rack::Test::Methods

      get "/admin/index"
      assert_equal 200, last_response.status
      assert_equal "Rendered from namespace", last_response.body
    end

    test "plugin with initializers" do
      $plugin_initializer = false
      @plugin.write "config/initializers/foo.rb", <<-RUBY
        $plugin_initializer = true
      RUBY

      boot_rails
      assert $plugin_initializer
    end

    test "plugin cannot declare an engine for it" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < Rails::Engine
          end
        end
      RUBY

      @plugin.write "init.rb", <<-RUBY
        require "bukkits"
      RUBY

      rescued = false

      begin
        boot_rails
      rescue Exception => e
        rescued = true
        assert_equal '"bukkits" is a Railtie/Engine and cannot be installed as plugin', e.message
      end

      assert rescued, "Expected boot rails to fail"
    end

    test "use plugin middleware in application config" do
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
