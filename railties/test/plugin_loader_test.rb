require File.dirname(__FILE__) + '/plugin_test_helper'

class TestPluginLoader < Test::Unit::TestCase
  def setup
    @initializer       = Rails::Initializer.new(Rails::Configuration.new)
    @valid_plugin_path = plugin_fixture_path('default/stubby')
    @empty_plugin_path = plugin_fixture_path('default/empty')
  end
  
  def test_determining_if_the_plugin_order_has_been_explicitly_set
    loader = loader_for(@valid_plugin_path)
    assert !loader.send(:explicit_plugin_loading_order?)
    only_load_the_following_plugins! %w(stubby acts_as_chunky_bacon)
    assert loader.send(:explicit_plugin_loading_order?)
  end
  
  def test_enabled_if_not_named_explicitly
    stubby_loader = loader_for(@valid_plugin_path)
    acts_as_loader = loader_for('acts_as/acts_as_chunky_bacon')
    
    only_load_the_following_plugins! ['stubby', :all]
    assert stubby_loader.send(:enabled?)
    assert acts_as_loader.send(:enabled?)
    
    assert stubby_loader.send(:explicitly_enabled?)
    assert !acts_as_loader.send(:explicitly_enabled?)
  end
  
  def test_determining_whether_a_given_plugin_is_loaded
    plugin_loader = loader_for(@valid_plugin_path)
    assert !plugin_loader.loaded?
    assert_nothing_raised do
      plugin_loader.send(:register_plugin_as_loaded)
    end
    assert plugin_loader.loaded?
  end
  
  def test_if_a_path_is_a_plugin_path
    # This is a plugin path, with a lib dir
    assert loader_for(@valid_plugin_path).plugin_path?
    # This just has an init.rb and no lib dir
    assert loader_for(plugin_fixture_path('default/plugin_with_no_lib_dir')).plugin_path?
    # This would be a plugin path, but the directory is empty
    assert !loader_for(plugin_fixture_path('default/empty')).plugin_path?
    # This is a non sense path
    assert !loader_for(plugin_fixture_path('default/this_directory_does_not_exist')).plugin_path?
  end
  
  def test_if_you_try_to_load_a_non_plugin_path_you_get_a_load_error
    # This path is fine so nothing is raised
    assert_nothing_raised do
      loader_for(@valid_plugin_path).send(:report_nonexistant_or_empty_plugin!)
    end
    
    # This is an empty path so it raises
    assert_raises(LoadError) do
      loader_for(@empty_plugin_path).send(:report_nonexistant_or_empty_plugin!)
    end
    
    assert_raises(LoadError) do
      loader_for('this_is_not_a_plugin_directory').send(:report_nonexistant_or_empty_plugin!)
    end
  end
  
  def test_loading_a_plugin_gives_the_init_file_access_to_all_it_needs
    failure_tip = "Perhaps someone has written another test that loads this same plugin and therefore makes the StubbyMixin constant defined already."
    assert !defined?(StubbyMixin), failure_tip
    assert !added_to_load_path?(@valid_plugin_path)
    # The init.rb of this plugin raises if it doesn't have access to all the things it needs
    assert_nothing_raised do
      loader_for(@valid_plugin_path).load
    end
    assert added_to_load_path?(@valid_plugin_path)
    assert defined?(StubbyMixin)
  end
  
  private
    def loader_for(path, initializer = @initializer)
      Rails::Plugin::Loader.new(initializer, path)
    end
    
    def plugin_fixture_path(path)
      File.join(plugin_fixture_root_path, path)
    end
    
    def added_to_load_path?(path)
      $LOAD_PATH.grep(/#{path}/).size == 1
    end
    
end