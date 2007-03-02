require File.dirname(__FILE__) + '/plugin_test_helper'

class TestPluginLocater < Test::Unit::TestCase
  def setup
    configuration = Rails::Configuration.new
    # We need to add our testing plugin directory to the plugin paths so
    # the locater knows where to look for our plugins
    configuration.plugin_paths << plugin_fixture_root_path
    @initializer = Rails::Initializer.new(configuration)
    @locater     = new_locater
  end
  
  def test_determining_if_the_plugin_order_has_been_explicitly_set
    assert !@locater.send(:explicit_plugin_loading_order?)
    only_load_the_following_plugins! %w(stubby acts_as_chunky_bacon)
    assert @locater.send(:explicit_plugin_loading_order?)
  end
  
  def test_no_plugins_are_loaded_if_the_configuration_has_an_empty_plugin_list
    only_load_the_following_plugins! []
    assert_equal [], @locater.plugins
  end
  
  def test_only_the_specified_plugins_are_located_in_the_order_listed
    plugin_names = %w(stubby acts_as_chunky_bacon)
    only_load_the_following_plugins! plugin_names
    assert_equal plugin_names, @locater.plugin_names
  end
  
  def test_registering_a_plugin_name_that_does_not_exist_raisesa_load_error
    only_load_the_following_plugins! %w(stubby acts_as_non_existant_plugin)
    assert_raises(LoadError) do
      @locater.plugin_names
    end
  end
  
  def test_all_plugins_are_loaded_when_registered_plugin_list_is_untouched
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_equal %w(a acts_as_chunky_bacon plugin_with_no_lib_dir stubby), @locater.plugin_names, failure_tip
  end
  
  private
    def new_locater(initializer = @initializer)
      Rails::Plugin::Locater.new(initializer)
    end
    
    def only_load_the_following_plugins!(plugins)
      @initializer.configuration.plugins = plugins
    end
      
end