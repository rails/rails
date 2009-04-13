require 'plugin_test_helper'

class PluginTest < Test::Unit::TestCase
  def setup
    @initializer         = Rails::Initializer.new(Rails::Configuration.new)
    @valid_plugin_path   = plugin_fixture_path('default/stubby')
    @empty_plugin_path   = plugin_fixture_path('default/empty')
    @gemlike_plugin_path = plugin_fixture_path('default/gemlike')
  end

  def test_should_determine_plugin_name_from_the_directory_of_the_plugin
    assert_equal 'stubby', plugin_for(@valid_plugin_path).name
    assert_equal 'empty', plugin_for(@empty_plugin_path).name
  end

  def test_should_not_be_loaded_when_created
    assert !plugin_for(@valid_plugin_path).loaded?
  end

  def test_should_be_marked_as_loaded_when_load_is_called
    plugin = plugin_for(@valid_plugin_path)
    assert !plugin.loaded?
    plugin.stubs(:evaluate_init_rb)
    assert_nothing_raised do
      plugin.send(:load, anything)
    end
    assert plugin.loaded?
  end

  def test_should_determine_validity_of_given_path
    # This is a plugin path, with a lib dir
    assert plugin_for(@valid_plugin_path).valid?
    # This just has an init.rb and no lib dir
    assert plugin_for(plugin_fixture_path('default/plugin_with_no_lib_dir')).valid?
    # This would be a plugin path, but the directory is empty
    assert !plugin_for(plugin_fixture_path('default/empty')).valid?
    # This is a non sense path
    assert !plugin_for(plugin_fixture_path('default/this_directory_does_not_exist')).valid?
  end

  def test_should_return_empty_array_for_load_paths_when_plugin_has_no_lib_directory
    assert_equal [], plugin_for(plugin_fixture_path('default/plugin_with_no_lib_dir')).load_paths
  end

  def test_should_return_array_with_lib_path_for_load_paths_when_plugin_has_a_lib_directory
    expected_lib_dir = File.join(plugin_fixture_path('default/stubby'), 'lib')
    assert_equal [expected_lib_dir], plugin_for(plugin_fixture_path('default/stubby')).load_paths
  end

  def test_should_raise_a_load_error_when_trying_to_determine_the_load_paths_from_an_invalid_plugin
    assert_nothing_raised do
      plugin_for(@valid_plugin_path).load_paths
    end
  
    assert_raise(LoadError) do
      plugin_for(@empty_plugin_path).load_paths
    end
  
    assert_raise(LoadError) do
      plugin_for('this_is_not_a_plugin_directory').load_paths
    end
  end

  def test_should_raise_a_load_error_when_trying_to_load_an_invalid_plugin
    # This path is fine so nothing is raised
    assert_nothing_raised do
      plugin = plugin_for(@valid_plugin_path)
      plugin.stubs(:evaluate_init_rb)
      plugin.send(:load, @initializer)
    end

    # This path is fine so nothing is raised
    assert_nothing_raised do
      plugin = plugin_for(@gemlike_plugin_path)
      plugin.stubs(:evaluate_init_rb)
      plugin.send(:load, @initializer)
    end

    # This is an empty path so it raises
    assert_raise(LoadError) do
      plugin = plugin_for(@empty_plugin_path)
      plugin.stubs(:evaluate_init_rb)      
      plugin.send(:load, @initializer)
    end
  
    assert_raise(LoadError) do
      plugin = plugin_for('this_is_not_a_plugin_directory')
      plugin.stubs(:evaluate_init_rb)
      plugin.send(:load, @initializer)
    end
  end
  
  def test_should_raise_a_load_error_when_trying_to_access_load_paths_of_an_invalid_plugin
    # This path is fine so nothing is raised
    assert_nothing_raised do
      plugin_for(@valid_plugin_path).load_paths
    end
  
    # This is an empty path so it raises
    assert_raise(LoadError) do
      plugin_for(@empty_plugin_path).load_paths
    end
  
    assert_raise(LoadError) do
      plugin_for('this_is_not_a_plugin_directory').load_paths
    end
  end    

  def test_loading_a_plugin_gives_the_init_file_access_to_all_it_needs
    failure_tip = "Perhaps someone has written another test that loads this same plugin and therefore makes the StubbyMixin constant defined already."
    assert !defined?(StubbyMixin), failure_tip
    plugin = plugin_for(@valid_plugin_path)
    plugin.load_paths.each { |path| $LOAD_PATH.unshift(path) }
    # The init.rb of this plugin raises if it doesn't have access to all the things it needs
    assert_nothing_raised do
      plugin.load(@initializer)
    end
    assert defined?(StubbyMixin)
  end
  
  def test_should_sort_naturally_by_name
    a = plugin_for("path/a")
    b = plugin_for("path/b")
    z = plugin_for("path/z")
    assert_equal [a, b, z], [b, z, a].sort
  end
  
  def test_should_only_be_loaded_once
    plugin = plugin_for(@valid_plugin_path)
    assert !plugin.loaded?
    plugin.expects(:evaluate_init_rb)
    assert_nothing_raised do
      plugin.send(:load, @initializer)
      plugin.send(:load, @initializer)
    end
    assert plugin.loaded?
  end
  
  def test_should_make_about_yml_available_as_about_method_on_plugin
    plugin = plugin_for(@valid_plugin_path)
    assert_equal "Plugin Author", plugin.about['author']
    assert_equal "1.0.0", plugin.about['version']
  end
  
  def test_should_return_empty_hash_for_about_if_about_yml_is_missing
    assert_equal({}, plugin_for(about_yml_plugin_path('plugin_without_about_yaml')).about)
  end
  
  def test_should_return_empty_hash_for_about_if_about_yml_is_malformed
    assert_equal({}, plugin_for(about_yml_plugin_path('bad_about_yml')).about)
  end

  private

    def about_yml_plugin_path(name)
      File.join(File.dirname(__FILE__), 'fixtures', 'about_yml_plugins', name)
    end

    def plugin_for(path)
      Rails::Plugin.new(path)
    end
end
