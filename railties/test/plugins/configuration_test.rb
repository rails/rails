require "isolation/abstract_unit"

module PluginsTest
  class ConfigurationTest < Test::Unit::TestCase
    def setup
      build_app
      boot_rails
      require "rails/all"
    end

    test "config is available to plugins" do
      class Foo < Rails::Railtie ; end
      assert_nil Foo.config.action_controller.foo
    end

    test "a config name is available for the plugin" do
      class Foo < Rails::Railtie ; config.foo.greetings = "hello" ; end
      assert_equal "hello", Foo.config.foo.greetings
    end

    test "plugin configurations are available in the application" do
      class Foo < Rails::Railtie ; config.foo.greetings = "hello" ; end
      require "#{app_path}/config/application"
      assert_equal "hello", AppTemplate::Application.config.foo.greetings
    end

    test "plugin config merges are deep" do
      class Foo < Rails::Railtie ; config.foo.greetings = 'hello' ; end
      class MyApp < Rails::Application
        config.foo.bar = "bar"
      end
      assert_equal "hello", MyApp.config.foo.greetings
      assert_equal "bar",   MyApp.config.foo.bar
    end

    test "plugin can add subscribers" do
      begin
        class Foo < Rails::Railtie; subscriber(Rails::Subscriber.new); end
        assert_kind_of Rails::Subscriber, Rails::Subscriber.subscribers[:foo]
      ensure
        Rails::Subscriber.subscribers.clear
      end
    end
  end
end
