# frozen_string_literal: true

require "isolation/abstract_unit"

module RailtiesTest
  class RailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "rails/all"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "cannot instantiate a Railtie object" do
      assert_raise(RuntimeError) { Rails::Railtie.send(:new) }
    end

    test "respond_to? works in the abstract railties" do
      assert_not_respond_to Rails::Railtie, :something_nice
    end

    test "method_missing works in the abstract railties" do
      assert_raise(NoMethodError) { Rails::Railtie.something_nice }
    end

    test "Railtie provides railtie_name" do
      class ::FooBarBaz < Rails::Railtie ; end
      assert_equal "foo_bar_baz", FooBarBaz.railtie_name
    ensure
      Object.send(:remove_const, :"FooBarBaz")
    end

    test "railtie_name can be set manually" do
      class Foo < Rails::Railtie
        railtie_name "bar"
      end
      assert_equal "bar", Foo.railtie_name
    end

    test "config is available to railtie" do
      class Foo < Rails::Railtie ; end
      assert_nil Foo.config.action_controller.foo
    end

    test "config name is available for the railtie" do
      class Foo < Rails::Railtie
        config.foo = ActiveSupport::OrderedOptions.new
        config.foo.greetings = "hello"
      end
      assert_equal "hello", Foo.config.foo.greetings
    end

    test "railtie configurations are available in the application" do
      class Foo < Rails::Railtie
        config.foo = ActiveSupport::OrderedOptions.new
        config.foo.greetings = "hello"
      end
      require "#{app_path}/config/application"
      assert_equal "hello", Rails.application.config.foo.greetings
    end

    test "railtie can add to_prepare callbacks" do
      $to_prepare = false
      class Foo < Rails::Railtie ; config.to_prepare { $to_prepare = true } ; end
      assert_not $to_prepare
      require "#{app_path}/config/environment"
      require "rack/test"
      extend Rack::Test::Methods
      get "/"
      assert $to_prepare
    end

    test "railtie have access to application in before_configuration callbacks" do
      $before_configuration = false
      class Foo < Rails::Railtie ; config.before_configuration { $before_configuration = Rails.root.to_path } ; end
      assert_not $before_configuration
      require "#{app_path}/config/environment"
      assert_equal app_path, $before_configuration
    end

    test "before_configuration callbacks run as soon as the application constant inherits from Rails::Application" do
      $before_configuration = false
      class Foo < Rails::Railtie ; config.before_configuration { $before_configuration = true } ; end
      class Application < Rails::Application ; end
      assert $before_configuration
    end

    test "railtie can add after_initialize callbacks" do
      $after_initialize = false
      class Foo < Rails::Railtie ; config.after_initialize { $after_initialize = true } ; end
      assert_not $after_initialize
      require "#{app_path}/config/environment"
      assert $after_initialize
    end

    test "rake_tasks block is executed when MyApp.load_tasks is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        rake_tasks do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert_not $ran_block
      require "rake"
      require "rake/testtask"
      require "rdoc/task"

      Rails.application.load_tasks
      assert $ran_block
    end

    test "rake_tasks block defined in superclass of railtie is also executed" do
      $ran_block = []

      class Rails::Railtie
        rake_tasks do
          $ran_block << railtie_name
        end
      end

      class MyTie < Rails::Railtie
        railtie_name "my_tie"
      end

      require "#{app_path}/config/environment"

      assert_equal [], $ran_block
      require "rake"
      require "rake/testtask"
      require "rdoc/task"

      Rails.application.load_tasks
      assert_includes $ran_block, "my_tie"
    end

    test "generators block is executed when MyApp.load_generators is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        generators do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert_not $ran_block
      Rails.application.load_generators
      assert $ran_block
    end

    test "console block is executed when MyApp.load_console is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        console do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert_not $ran_block
      Rails.application.load_console
      assert $ran_block
    end

    test "server block is executed when MyApp.load_server is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        server do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert_not $ran_block
      Rails.application.load_server
      assert $ran_block
    end

    test "runner block is executed when MyApp.load_runner is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        runner do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert_not $ran_block
      Rails.application.load_runner
      assert $ran_block
    end

    test "railtie can add initializers" do
      $ran_block = false

      class MyTie < Rails::Railtie
        initializer :something_nice do
          $ran_block = true
        end
      end

      assert_not $ran_block
      require "#{app_path}/config/environment"
      assert $ran_block
    end

    test "we can change our environment if we want to" do
      original_env = Rails.env
      Rails.env = "foo"
      assert_equal("foo", Rails.env)
    ensure
      Rails.env = original_env
      assert_equal(original_env, Rails.env)
    end

    test "Railtie object isn't output when a NoMethodError is raised" do
      class Foo < Rails::Railtie
        config.foo = ActiveSupport::OrderedOptions.new
        config.foo.greetings = "hello"
      end

      error = assert_raises(NoMethodError) do
        Foo.instance.abc
      end

      assert_match(/undefined method [`']abc' for.*RailtiesTest::RailtieTest::Foo/, error.original_message)
    end

    test "rake environment can be called in the ralitie" do
      $ran_block = false

      class MyTie < Rails::Railtie
        rake_tasks do
          $ran_block = true
        end
      end

      ::APP_RAKEFILE = "#{app_path}/Rakefile"
      require "#{app_path}/config/environment"

      assert_not $ran_block
      require "rake"
      require "rake/testtask"
      require "rdoc/task"
      load "rails/tasks/engine.rake"

      assert $ran_block
    end
  end
end
