require 'plugin_test_helper'

class PluginLocatorTest < Test::Unit::TestCase
  def test_should_require_subclasses_to_implement_the_plugins_method
    assert_raises(RuntimeError) do
      Rails::Plugin::Locator.new(nil).plugins
    end
  end

  def test_should_iterator_over_plugins_returned_by_plugins_when_calling_each
    locator = Rails::Plugin::Locator.new(nil)
    locator.stubs(:plugins).returns([:a, :b, :c])
    plugin_consumer = mock
    plugin_consumer.expects(:consume).with(:a)
    plugin_consumer.expects(:consume).with(:b)
    plugin_consumer.expects(:consume).with(:c)
  
    locator.each do |plugin|
      plugin_consumer.consume(plugin)
    end
  end
end

class PluginFileSystemLocatorTest < Test::Unit::TestCase
  def setup
    @configuration = Rails::Configuration.new
    # We need to add our testing plugin directory to the plugin paths so
    # the locator knows where to look for our plugins
    @configuration.plugin_paths << plugin_fixture_root_path
    @initializer       = Rails::Initializer.new(@configuration)
    @locator           = Rails::Plugin::FileSystemLocator.new(@initializer)
    @valid_plugin_path = plugin_fixture_path('default/stubby')
    @empty_plugin_path = plugin_fixture_path('default/empty')
  end

  def test_should_return_rails_plugin_instances_when_calling_create_plugin_with_a_valid_plugin_directory
    assert_kind_of Rails::Plugin, @locator.send(:create_plugin, @valid_plugin_path)  
  end

  def test_should_return_nil_when_calling_create_plugin_with_an_invalid_plugin_directory
    assert_nil @locator.send(:create_plugin, @empty_plugin_path)  
  end

  def test_should_return_all_plugins_found_under_the_set_plugin_paths
    assert_equal ["a", "acts_as_chunky_bacon", "engine", "gemlike", "plugin_with_no_lib_dir", "stubby"].sort, @locator.plugins.map(&:name).sort
  end

  def test_should_find_plugins_only_under_the_plugin_paths_set_in_configuration
    @configuration.plugin_paths = [File.join(plugin_fixture_root_path, "default")]
    assert_equal ["acts_as_chunky_bacon", "gemlike", "plugin_with_no_lib_dir", "stubby"].sort, @locator.plugins.map(&:name).sort
  
    @configuration.plugin_paths = [File.join(plugin_fixture_root_path, "alternate")]
    assert_equal ["a"], @locator.plugins.map(&:name)
  end

  def test_should_not_raise_any_error_and_return_no_plugins_if_the_plugin_path_value_does_not_exist
    @configuration.plugin_paths = ["some_missing_directory"]
    assert_nothing_raised do
      assert @locator.plugins.empty?
    end
  end
end
