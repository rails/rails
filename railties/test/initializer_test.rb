require 'abstract_unit'
require 'initializer'

# Mocks out the configuration
module Rails
  def self.configuration
    Rails::Configuration.new
  end
end

class ConfigurationMock < Rails::Configuration
  attr_reader :environment_path

  def initialize(envpath)
    super()
    @environment_path = envpath
  end
end

class Initializer_load_environment_Test < Test::Unit::TestCase

  def test_load_environment_with_constant
    config = ConfigurationMock.new("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")
    assert_nil $initialize_test_set_from_env
    Rails::Initializer.run(:load_environment, config)
    assert_equal "success", $initialize_test_set_from_env
  ensure
    $initialize_test_set_from_env = nil
  end

end

class Initializer_eager_loading_Test < Test::Unit::TestCase
  def setup
    @config = ConfigurationMock.new("")
    @config.cache_classes = true
    @config.load_paths = [File.expand_path(File.dirname(__FILE__) + "/fixtures/eager")]
    @config.eager_load_paths = [File.expand_path(File.dirname(__FILE__) + "/fixtures/eager")]
    @initializer = Rails::Initializer.new(@config)
    @initializer.set_load_path
    @initializer.set_autoload_paths
  end

  def test_eager_loading_loads_parent_classes_before_children
    assert_nothing_raised do
      @initializer.load_application_classes
    end
  end
end

uses_mocha 'Initializer after_initialize' do
  class Initializer_after_initialize_with_blocks_environment_Test < Test::Unit::TestCase
    def setup
      config = ConfigurationMock.new("")
      config.after_initialize do
        $test_after_initialize_block1 = "success"
      end
      config.after_initialize do
        $test_after_initialize_block2 = "congratulations"
      end
      assert_nil $test_after_initialize_block1
      assert_nil $test_after_initialize_block2

      Rails::Initializer.any_instance.expects(:gems_dependencies_loaded).returns(true)
      Rails::Initializer.run(:after_initialize, config)
    end

    def teardown
      $test_after_initialize_block1 = nil
      $test_after_initialize_block2 = nil
    end

    def test_should_have_called_the_first_after_initialize_block
      assert_equal "success", $test_after_initialize_block1
    end

    def test_should_have_called_the_second_after_initialize_block
      assert_equal "congratulations", $test_after_initialize_block2
    end
  end

  class Initializer_after_initialize_with_no_block_environment_Test < Test::Unit::TestCase
    def setup
      config = ConfigurationMock.new("")
      config.after_initialize do
        $test_after_initialize_block1 = "success"
      end
      config.after_initialize # don't pass a block, this is what we're testing!
      config.after_initialize do
        $test_after_initialize_block2 = "congratulations"
      end
      assert_nil $test_after_initialize_block1

      Rails::Initializer.any_instance.expects(:gems_dependencies_loaded).returns(true)
      Rails::Initializer.run(:after_initialize, config)
    end

    def teardown
      $test_after_initialize_block1 = nil
      $test_after_initialize_block2 = nil
    end

    def test_should_have_called_the_first_after_initialize_block
      assert_equal "success", $test_after_initialize_block1, "should still get set"
    end

    def test_should_have_called_the_second_after_initialize_block
      assert_equal "congratulations", $test_after_initialize_block2
    end
  end
end

uses_mocha 'framework paths' do
  class ConfigurationFrameworkPathsTests < Test::Unit::TestCase
    def setup
      @config = Rails::Configuration.new
      @config.frameworks.clear

      File.stubs(:directory?).returns(true)
      @config.stubs(:framework_root_path).returns('')
    end

    def test_minimal
      expected = %w(
        /railties
        /railties/lib
        /activesupport/lib
      )
      assert_equal expected, @config.framework_paths
    end

    def test_actioncontroller_or_actionview_add_actionpack
      @config.frameworks << :action_controller
      assert_framework_path '/actionpack/lib'

      @config.frameworks = [:action_view]
      assert_framework_path '/actionpack/lib'
    end

    def test_paths_for_ar_ares_and_mailer
      [:active_record, :action_mailer, :active_resource, :action_web_service].each do |framework|
        @config.frameworks = [framework]
        assert_framework_path "/#{framework.to_s.gsub('_', '')}/lib"
      end
    end

    def test_unknown_framework_raises_error
      @config.frameworks << :action_foo
      initializer = Rails::Initializer.new @config
      initializer.expects(:require).raises(LoadError)

      assert_raise RuntimeError do
        initializer.send :require_frameworks
      end
    end

    def test_action_mailer_load_paths_set_only_if_action_mailer_in_use
      @config.frameworks = [:action_controller]
      initializer = Rails::Initializer.new @config
      initializer.send :require_frameworks

      assert_nothing_raised NameError do
        initializer.send :load_view_paths
      end
    end

    def test_action_controller_load_paths_set_only_if_action_controller_in_use
      @config.frameworks = []
      initializer = Rails::Initializer.new @config
      initializer.send :require_frameworks

      assert_nothing_raised NameError do
        initializer.send :load_view_paths
      end
    end

    protected
      def assert_framework_path(path)
        assert @config.framework_paths.include?(path),
          "<#{path.inspect}> not found among <#{@config.framework_paths.inspect}>"
      end
  end
end

uses_mocha "Initializer plugin loading tests" do
  require File.dirname(__FILE__) + '/plugin_test_helper'

  class InitializerPluginLoadingTests < Test::Unit::TestCase
    def setup
      @configuration     = Rails::Configuration.new
      @configuration.plugin_paths << plugin_fixture_root_path
      @initializer       = Rails::Initializer.new(@configuration)
      @valid_plugin_path = plugin_fixture_path('default/stubby')
      @empty_plugin_path = plugin_fixture_path('default/empty')
    end

    def test_no_plugins_are_loaded_if_the_configuration_has_an_empty_plugin_list
      only_load_the_following_plugins! []
      @initializer.load_plugins
      assert_equal [], @initializer.loaded_plugins
    end

    def test_only_the_specified_plugins_are_located_in_the_order_listed
      plugin_names = [:plugin_with_no_lib_dir, :acts_as_chunky_bacon]
      only_load_the_following_plugins! plugin_names
      load_plugins!
      assert_plugins plugin_names, @initializer.loaded_plugins
    end

    def test_all_plugins_are_loaded_when_registered_plugin_list_is_untouched
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      load_plugins!
      assert_plugins [:a, :acts_as_chunky_bacon, :gemlike, :plugin_with_no_lib_dir, :stubby], @initializer.loaded_plugins, failure_tip
    end

    def test_all_plugins_loaded_when_all_is_used
      plugin_names = [:stubby, :acts_as_chunky_bacon, :all]
      only_load_the_following_plugins! plugin_names
      load_plugins!
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:stubby, :acts_as_chunky_bacon, :a, :gemlike, :plugin_with_no_lib_dir], @initializer.loaded_plugins, failure_tip
    end

    def test_all_plugins_loaded_after_all
      plugin_names = [:stubby, :all, :acts_as_chunky_bacon]
      only_load_the_following_plugins! plugin_names
      load_plugins!
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:stubby, :a, :gemlike, :plugin_with_no_lib_dir, :acts_as_chunky_bacon], @initializer.loaded_plugins, failure_tip
    end

    def test_plugin_names_may_be_strings
      plugin_names = ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
      only_load_the_following_plugins! plugin_names
      load_plugins!
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins plugin_names, @initializer.loaded_plugins, failure_tip
    end

    def test_registering_a_plugin_name_that_does_not_exist_raises_a_load_error
      only_load_the_following_plugins! [:stubby, :acts_as_a_non_existant_plugin]
      assert_raises(LoadError) do
        load_plugins!
      end
    end

    def test_should_ensure_all_loaded_plugins_load_paths_are_added_to_the_load_path
      only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon]

      @initializer.add_plugin_load_paths

      assert $LOAD_PATH.include?(File.join(plugin_fixture_path('default/stubby'), 'lib'))
      assert $LOAD_PATH.include?(File.join(plugin_fixture_path('default/acts/acts_as_chunky_bacon'), 'lib'))
    end

    private

      def load_plugins!
        @initializer.add_plugin_load_paths
        @initializer.load_plugins
      end
  end

end
