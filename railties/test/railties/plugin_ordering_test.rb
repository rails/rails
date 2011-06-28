require "isolation/abstract_unit"

module RailtiesTest
  class PluginOrderingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      $arr = []
      plugin "a_plugin", "$arr << :a"
      plugin "b_plugin", "$arr << :b"
      plugin "c_plugin", "$arr << :c"
    end

    def teardown
      teardown_app
    end

    def boot_rails
      super
      require "#{app_path}/config/environment"
    end

    test "plugins are loaded alphabetically by default" do
      boot_rails
      assert_equal [:a, :b, :c], $arr
    end

    test "if specified, only those plugins are loaded" do
      add_to_config "config.plugins = [:b_plugin]"
      boot_rails
      assert_equal [:b], $arr
    end

    test "the plugins are initialized in the order they are specified" do
      add_to_config "config.plugins = [:b_plugin, :a_plugin]"
      boot_rails
      assert_equal [:b, :a], $arr
    end

    test "if :all is specified, the remaining plugins are loaded in alphabetical order" do
      add_to_config "config.plugins = [:c_plugin, :all]"
      boot_rails
      assert_equal [:c, :a, :b], $arr
    end

    test "if :all is at the beginning, it represents the plugins not otherwise specified" do
      add_to_config "config.plugins = [:all, :b_plugin]"
      boot_rails
      assert_equal [:a, :c, :b], $arr
    end

    test "plugin order array is strings" do
      add_to_config "config.plugins = %w( c_plugin all )"
      boot_rails
      assert_equal [:c, :a, :b], $arr
    end

    test "can require lib file from a different plugin" do
      plugin "foo", "require 'bar'" do |plugin|
        plugin.write "lib/foo.rb", "$foo = true"
      end

      plugin "bar", "require 'foo'" do |plugin|
        plugin.write "lib/bar.rb", "$bar = true"
      end

      add_to_config "config.plugins = [:foo, :bar]"

      boot_rails

      assert $foo
      assert $bar
    end
  end
end
