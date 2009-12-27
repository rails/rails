require "isolation/abstract_unit"

module PluginsTest
  class ConfigurationTest < Test::Unit::TestCase
    def setup
      build_app
      boot_rails
      require "rails"
    end

    module Bar; end
    module Baz; end
    module All; end

    test "config is available to plugins" do
      class Foo < Rails::Plugin ; end
      assert_nil Foo.config.action_controller.foo
    end

    test "a config name is available for the plugin" do
      class Foo < Rails::Plugin ; config.foo.greetings = "hello" ; end
      assert_equal "hello", Foo.config.foo.greetings
    end

    test "plugin configurations are available in the application" do
      class Foo < Rails::Plugin ; config.foo.greetings = "hello" ; end
      require "#{app_path}/config/application"
      assert_equal "hello", AppTemplate::Application.config.foo.greetings
    end

    test "plugin configurations allow modules to be given" do
      class Foo < Rails::Plugin ; config.foo.include(Bar, Baz) ; end
      assert_equal [Bar, Baz], Foo.config.foo.includes
    end

    test "plugin includes given modules in given class" do
      class Foo < Rails::Plugin ; config.foo.include(Bar, "PluginsTest::ConfigurationTest::Baz") ; include_modules_in All ; end
      Foo.new.run_initializers(Foo)
      assert All.ancestors.include?(Bar)
      assert All.ancestors.include?(Baz)
    end

    test "plugin config merges are deep" do
      class Foo < Rails::Plugin ; config.foo.greetings = 'hello' ; end
      class MyApp < Rails::Application
        config.foo.bar = "bar"
      end
      assert_equal "hello", MyApp.config.foo.greetings
      assert_equal "bar",   MyApp.config.foo.bar
    end
  end
end
