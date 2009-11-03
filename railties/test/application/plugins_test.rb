require "isolation/abstract_unit"

module ApplicationTests
  class PluginTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def assert_plugins(list_of_names, array_of_plugins, message=nil)
      assert_equal list_of_names.map { |n| n.to_s }, array_of_plugins.map { |p| p.name }, message
    end

    def setup
      build_app
      boot_rails
      require "rails"
      @failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      # Tmp hax to get tests working
      FileUtils.cp_r "#{File.dirname(__FILE__)}/../fixtures/plugins", "#{app_path}/vendor"
    end

    test "all plugins are loaded when registered plugin list is untouched" do
      Rails::Initializer.run { |c| c.root = app_path }
      Rails.initialize!
      assert_plugins [
        :a, :acts_as_chunky_bacon, :engine, :gemlike, :plugin_with_no_lib_dir, :stubby
      ], Rails.application.config.loaded_plugins, @failure_tip
    end

    test "no plugins are loaded if the configuration has an empty plugin list" do
      Rails::Initializer.run { |c| c.root = app_path; c.plugins = [] }
      assert_plugins [], Rails.application.config.loaded_plugins
    end

    test "only the specified plugins are located in the order listed" do
      plugin_names = [:plugin_with_no_lib_dir, :acts_as_chunky_bacon]
      Rails::Initializer.run { |c| c.root = app_path; c.plugins = plugin_names }
      Rails.initialize!
      assert_plugins plugin_names, Rails.application.config.loaded_plugins
    end

    test "all plugins loaded after all" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.plugins = [:stubby, :all, :acts_as_chunky_bacon]
      end
      Rails.initialize!
      assert_plugins [:stubby, :a, :engine, :gemlike, :plugin_with_no_lib_dir, :acts_as_chunky_bacon], Rails.application.config.loaded_plugins, @failure_tip
    end

    test "plugin names may be strings" do
      plugin_names = ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
      Rails::Initializer.run do |config|
        config.root = app_path
        config.plugins = ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
      end
      Rails.initialize!

      assert_plugins plugin_names, Rails.application.config.loaded_plugins, @failure_tip
    end

    test "all plugins loaded when all is used" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.plugins = [:stubby, :acts_as_chunky_bacon, :all]
      end
      Rails.initialize!

      assert_plugins [:stubby, :acts_as_chunky_bacon, :a, :engine, :gemlike, :plugin_with_no_lib_dir], Rails.application.config.loaded_plugins, @failure_tip
    end

    test "all loaded plugins are added to the load paths" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.plugins = [:stubby, :acts_as_chunky_bacon]
      end
      Rails.initialize!

      assert $LOAD_PATH.include?("#{app_path}/vendor/plugins/default/stubby/lib")
      assert $LOAD_PATH.include?("#{app_path}/vendor/plugins/default/acts/acts_as_chunky_bacon/lib")
    end

    test "registering a plugin name that does not exist raises a load error" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.plugins = [:stubby, :acts_as_a_non_existant_plugin]
      end

      assert_raise(LoadError) do
        Rails.initialize!
      end
    end

    test "load error messages mention missing plugins and no others" do
      valid_plugins   = [:stubby, :acts_as_chunky_bacon]
      invalid_plugins = [:non_existant_plugin1, :non_existant_plugin2]

      begin
        Rails::Initializer.run do |config|
          config.root = app_path
          config.plugins = [:stubby, :acts_as_chunky_bacon, :non_existant_plugin1, :non_existant_plugin2]
        end
        Rails.initialize!
        flunk "Expected a LoadError but did not get one"
      rescue LoadError => e
        assert_plugins valid_plugins, Rails.application.config.loaded_plugins, @failure_tip

        invalid_plugins.each do |plugin|
          assert_match(/#{plugin.to_s}/, e.message, "LoadError message should mention plugin '#{plugin}'")
        end

        valid_plugins.each do |plugin|
          assert_no_match(/#{plugin.to_s}/, e.message, "LoadError message should not mention '#{plugin}'")
        end
      end
    end

  end
end