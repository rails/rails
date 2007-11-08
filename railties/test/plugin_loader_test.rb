require File.dirname(__FILE__) + '/plugin_test_helper'

uses_mocha "Plugin Loader Tests" do

  class TestPluginLoader < Test::Unit::TestCase
    ORIGINAL_LOAD_PATH = $LOAD_PATH.dup
    
    def setup
      reset_load_path!
      
      @configuration     = Rails::Configuration.new
      @configuration.plugin_paths << plugin_fixture_root_path
      @initializer       = Rails::Initializer.new(@configuration)
      @valid_plugin_path = plugin_fixture_path('default/stubby')
      @empty_plugin_path = plugin_fixture_path('default/empty')
      
      @loader = Rails::Plugin::Loader.new(@initializer)
    end

    def test_should_locate_plugins_by_asking_each_locator_specifed_in_configuration_for_its_plugins_result
      locator_1 = stub(:plugins => [:a, :b, :c])
      locator_2 = stub(:plugins => [:d, :e, :f])
      locator_class_1 = stub(:new => locator_1)
      locator_class_2 = stub(:new => locator_2)
      @configuration.plugin_locators = [locator_class_1, locator_class_2]
      assert_equal [:a, :b, :c, :d, :e, :f], @loader.send(:locate_plugins)
    end
    
    def test_should_memoize_the_result_of_locate_plugins_as_all_plugins
      plugin_list = [:a, :b, :c]
      @loader.expects(:locate_plugins).once.returns(plugin_list)
      assert_equal plugin_list, @loader.all_plugins
      assert_equal plugin_list, @loader.all_plugins # ensuring that locate_plugins isn't called again
    end
    
    def test_should_return_empty_array_if_configuration_plugins_is_empty
      @configuration.plugins = []
      assert_equal [], @loader.plugins
    end
    
    def test_should_find_all_availble_plugins_and_return_as_all_plugins
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:a, :acts_as_chunky_bacon, :plugin_with_no_lib_dir, :stubby], @loader.all_plugins, failure_tip      
    end

    def test_should_return_all_plugins_as_plugins_when_registered_plugin_list_is_untouched
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:a, :acts_as_chunky_bacon, :plugin_with_no_lib_dir, :stubby], @loader.plugins, failure_tip
    end
    
    def test_should_return_all_plugins_as_plugins_when_registered_plugin_list_is_nil
      @configuration.plugins = nil
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:a, :acts_as_chunky_bacon, :plugin_with_no_lib_dir, :stubby], @loader.plugins, failure_tip
    end

    def test_should_return_specific_plugins_named_in_config_plugins_array_if_set
      plugin_names = [:acts_as_chunky_bacon, :stubby]
      only_load_the_following_plugins! plugin_names
      assert_plugins plugin_names, @loader.plugins
    end
    
    def test_should_respect_the_order_of_plugins_given_in_configuration
      plugin_names = [:stubby, :acts_as_chunky_bacon]
      only_load_the_following_plugins! plugin_names
      assert_plugins plugin_names, @loader.plugins      
    end
    
    def test_should_load_all_plugins_in_natural_order_when_all_is_used
      only_load_the_following_plugins! [:all]
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:a, :acts_as_chunky_bacon, :plugin_with_no_lib_dir, :stubby], @loader.plugins, failure_tip
    end
    
    def test_should_load_specified_plugins_in_order_and_then_all_remaining_plugins_when_all_is_used
      only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon, :all]
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:stubby, :acts_as_chunky_bacon, :a, :plugin_with_no_lib_dir], @loader.plugins, failure_tip
    end
    
    def test_should_be_able_to_specify_loading_of_plugins_loaded_after_all
      only_load_the_following_plugins!  [:stubby, :all, :acts_as_chunky_bacon]
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:stubby, :a, :plugin_with_no_lib_dir, :acts_as_chunky_bacon], @loader.plugins, failure_tip
    end

    def test_should_accept_plugin_names_given_as_strings
      only_load_the_following_plugins! ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
      failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
      assert_plugins [:stubby, :acts_as_chunky_bacon, :a, :plugin_with_no_lib_dir], @loader.plugins, failure_tip
    end
    
    def test_should_add_plugin_load_paths_to_global_LOAD_PATH_array
      only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon]
      stubbed_application_lib_index_in_LOAD_PATHS = 5
      @loader.stubs(:application_lib_index).returns(stubbed_application_lib_index_in_LOAD_PATHS)
      
      @loader.add_plugin_load_paths
      
      assert $LOAD_PATH.index(File.join(plugin_fixture_path('default/stubby'), 'lib')) >= stubbed_application_lib_index_in_LOAD_PATHS
      assert $LOAD_PATH.index(File.join(plugin_fixture_path('default/acts/acts_as_chunky_bacon'), 'lib')) >= stubbed_application_lib_index_in_LOAD_PATHS    
    end   
    
    def test_should_add_plugin_load_paths_to_Dependencies_load_paths
      only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon]

      @loader.add_plugin_load_paths
      
      assert Dependencies.load_paths.include?(File.join(plugin_fixture_path('default/stubby'), 'lib'))
      assert Dependencies.load_paths.include?(File.join(plugin_fixture_path('default/acts/acts_as_chunky_bacon'), 'lib'))    
    end
    
    def test_should_add_plugin_load_paths_to_Dependencies_load_once_paths
      only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon]

      @loader.add_plugin_load_paths
      
      assert Dependencies.load_once_paths.include?(File.join(plugin_fixture_path('default/stubby'), 'lib'))
      assert Dependencies.load_once_paths.include?(File.join(plugin_fixture_path('default/acts/acts_as_chunky_bacon'), 'lib'))    
    end
    
    def test_should_add_all_load_paths_from_a_plugin_to_LOAD_PATH_array
      plugin_load_paths = ["a", "b"]
      plugin = stub(:load_paths => plugin_load_paths)
      @loader.stubs(:plugins).returns([plugin])
      
      @loader.add_plugin_load_paths
      
      plugin_load_paths.each { |path| assert $LOAD_PATH.include?(path) }
    end
    
    private
    
      def reset_load_path!
        $LOAD_PATH.clear
        ORIGINAL_LOAD_PATH.each { |path| $LOAD_PATH << path }        
      end
  end
    
end