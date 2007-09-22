require File.dirname(__FILE__) + '/plugin_test_helper'

class TestPluginFileSystemLocator < Test::Unit::TestCase
  def setup
    configuration = Rails::Configuration.new
    # We need to add our testing plugin directory to the plugin paths so
    # the locator knows where to look for our plugins
    configuration.plugin_paths << plugin_fixture_root_path
    @initializer = Rails::Initializer.new(configuration)
    @locator     = new_locator
  end
  
  def test_no_plugins_are_loaded_if_the_configuration_has_an_empty_plugin_list
    only_load_the_following_plugins! []
    assert_equal [], @locator.plugins
  end
  
  def test_only_the_specified_plugins_are_located_in_the_order_listed
    plugin_names = [:stubby, :acts_as_chunky_bacon]
    only_load_the_following_plugins! plugin_names
    assert_equal plugin_names, @locator.plugin_names
  end
  
  def test_all_plugins_are_loaded_when_registered_plugin_list_is_untouched
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_equal [:a, :acts_as_chunky_bacon, :plugin_with_no_lib_dir, :stubby], @locator.plugin_names, failure_tip
  end
  
  def test_all_plugins_loaded_when_all_is_used
    plugin_names = [:stubby, :acts_as_chunky_bacon, :all]
    only_load_the_following_plugins! plugin_names
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_equal [:stubby, :acts_as_chunky_bacon, :a, :plugin_with_no_lib_dir], @locator.plugin_names, failure_tip
  end
  
  def test_all_plugins_loaded_after_all
    plugin_names = [:stubby, :all, :acts_as_chunky_bacon]
    only_load_the_following_plugins! plugin_names
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_equal [:stubby, :a, :plugin_with_no_lib_dir, :acts_as_chunky_bacon], @locator.plugin_names, failure_tip
  end
  
  def test_plugin_names_may_be_strings
    plugin_names = ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
    only_load_the_following_plugins! plugin_names
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_equal [:stubby, :acts_as_chunky_bacon, :a, :plugin_with_no_lib_dir], @locator.plugin_names, failure_tip
  end
  
  def test_registering_a_plugin_name_that_does_not_exist_raises_a_load_error
    only_load_the_following_plugins! [:stubby, :acts_as_a_non_existant_plugin]
    assert_raises(LoadError) do
      @initializer.load_plugins
    end
  end
  
  private
    def new_locator(initializer = @initializer)
      Rails::Plugin::FileSystemLocator.new(initializer)
    end   
end