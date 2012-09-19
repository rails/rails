require "isolation/abstract_unit"

module RailtiesTest
  class RailtieTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "rails/all"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "Rails::Railtie itself does not respond to config" do
      assert !Rails::Railtie.respond_to?(:config)
    end

    test "Railtie provides railtie_name" do
      begin
        class ::FooBarBaz < Rails::Railtie ; end
        assert_equal "foo_bar_baz", ::FooBarBaz.railtie_name
      ensure
        Object.send(:remove_const, :"FooBarBaz")
      end
    end

    test "railtie_name can be set manualy" do
      class Foo < Rails::Railtie
        railtie_name "bar"
      end
      assert_equal "bar", Foo.railtie_name
    end

    test "cannot inherit from a railtie" do
      class Foo < Rails::Railtie ; end
      assert_raise RuntimeError do
        class Bar < Foo; end
      end
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
      assert_equal "hello", AppTemplate::Application.config.foo.greetings
    end

    test "railtie can add to_prepare callbacks" do
      $to_prepare = false
      class Foo < Rails::Railtie ; config.to_prepare { $to_prepare = true } ; end
      assert !$to_prepare
      require "#{app_path}/config/environment"
      require "rack/test"
      extend Rack::Test::Methods
      get "/"
      assert $to_prepare
    end

    test "railtie can add after_initialize callbacks" do
      $after_initialize = false
      class Foo < Rails::Railtie ; config.after_initialize { $after_initialize = true } ; end
      assert !$after_initialize
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

      assert !$ran_block
      require 'rake'
      require 'rake/testtask'
      require 'rdoc/task'

      AppTemplate::Application.load_tasks
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
      require 'rake'
      require 'rake/testtask'
      require 'rdoc/task'

      AppTemplate::Application.load_tasks
      assert $ran_block.include?("my_tie")
    end

    test "generators block is executed when MyApp.load_generators is called" do
      $ran_block = false

      class MyTie < Rails::Railtie
        generators do
          $ran_block = true
        end
      end

      require "#{app_path}/config/environment"

      assert !$ran_block
      AppTemplate::Application.load_generators
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

      assert !$ran_block
      AppTemplate::Application.load_console
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

      assert !$ran_block
      AppTemplate::Application.load_runner
      assert $ran_block
    end

    test "railtie can add initializers" do
      $ran_block = false

      class MyTie < Rails::Railtie
        initializer :something_nice do
          $ran_block = true
        end
      end

      assert !$ran_block
      require "#{app_path}/config/environment"
      assert $ran_block
    end

    test "we can change our environment if we want to" do
      begin
        original_env = Rails.env
        Rails.env = 'foo'
        assert_equal('foo', Rails.env)
      ensure
        Rails.env = original_env
        assert_equal(original_env, Rails.env)
      end
    end

    test "we cannot change the Rails field when it is locked" do
      begin
        original_env = Rails.env
        Rails.lock!
        assert_raise RuntimeError do 
          Rails.env = 'foo'
        end
        assert_raise RuntimeError do
          Rails.logger = Logger.new($stdout)
        end
        assert_raise RuntimeError do
          Rails.application = nil
        end
      ensure
        Rails.unlock!
        Rails.env = original_env
        assert_equal(original_env, Rails.env)
      end
    end
  end
end
