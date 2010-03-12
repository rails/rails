require "isolation/abstract_unit"

module RailtiesTest
  class RailtieTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
      require "rails/all"
    end

    def app
      @app ||= Rails.application
    end

    test "Rails::Railtie itself does not respond to config" do
      assert !Rails::Railtie.respond_to?(:config)
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
      class Foo < Rails::Railtie ; config.foo.greetings = "hello" ; end
      assert_equal "hello", Foo.config.foo.greetings
    end

    test "railtie configurations are available in the application" do
      class Foo < Rails::Railtie ; config.foo.greetings = "hello" ; end
      require "#{app_path}/config/application"
      assert_equal "hello", AppTemplate::Application.config.foo.greetings
    end

    test "railtie config merges are deep" do
      class Foo < Rails::Railtie ; config.foo.greetings = 'hello' ; end
      class Bar < Rails::Railtie
        config.foo.bar = "bar"
      end
      assert_equal "hello", Bar.config.foo.greetings
      assert_equal "bar",   Bar.config.foo.bar
    end

    test "railtie can add log subscribers" do
      begin
        class Foo < Rails::Railtie ; log_subscriber(Rails::LogSubscriber.new) ; end
        assert_kind_of Rails::LogSubscriber, Rails::LogSubscriber.log_subscribers[0]
      ensure
        Rails::LogSubscriber.log_subscribers.clear
      end
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
      require 'rake/rdoctask'

      AppTemplate::Application.load_tasks
      assert $ran_block
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
  end
end
