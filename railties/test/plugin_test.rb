$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'
require 'initializer'

unless defined?(RAILS_ROOT)
  module Rails
    class Initializer
      RAILS_ROOT = '.'
    end
  end
end

class PluginTest < Test::Unit::TestCase
  class TestConfig < Rails::Configuration
    protected
      def root_path
        File.dirname(__FILE__)
      end
  end

  def setup
    @init = Rails::Initializer.new(TestConfig.new)
  end

  def test_plugin_path?
    assert @init.send(:plugin_path?, "#{File.dirname(__FILE__)}/fixtures/plugins/default/stubby")
    assert !@init.send(:plugin_path?, "#{File.dirname(__FILE__)}/fixtures/plugins/default/empty")
    assert !@init.send(:plugin_path?, "#{File.dirname(__FILE__)}/fixtures/plugins/default/jalskdjflkas")
  end

  def test_find_plugins
    base    = "#{File.dirname(__FILE__)}/fixtures/plugins"
    default = "#{base}/default"
    alt     = "#{base}/alternate"
    acts    = "#{default}/acts"
    assert_equal ["#{acts}/acts_as_chunky_bacon"], @init.send(:find_plugins, acts)
    assert_equal ["#{acts}/acts_as_chunky_bacon", "#{default}/stubby"], @init.send(:find_plugins, default).sort
    assert_equal ["#{alt}/a", "#{acts}/acts_as_chunky_bacon", "#{default}/stubby"], @init.send(:find_plugins, base).sort
  end

  def test_load_plugin
    stubby = "#{File.dirname(__FILE__)}/fixtures/plugins/default/stubby"
    expected = ['stubby']

    assert @init.send(:load_plugin, stubby)
    assert_equal expected, @init.loaded_plugins

    assert !@init.send(:load_plugin, stubby)
    assert_equal expected, @init.loaded_plugins

    assert_raise(LoadError) { @init.send(:load_plugin, 'lakjsdfkasljdf') }
    assert_equal expected, @init.loaded_plugins
  end

  def test_load_default_plugins
    assert_loaded_plugins %w(stubby acts_as_chunky_bacon), 'default'
  end

  def test_load_alternate_plugins
    assert_loaded_plugins %w(a), 'alternate'
  end

  def test_load_plugins_from_two_sources
    assert_loaded_plugins %w(a stubby acts_as_chunky_bacon), ['default', 'alternate']
  end
 
  def test_load_all_plugins_when_config_plugins_is_nil
    @init.configuration.plugins = nil
    assert_loaded_plugins %w(a stubby acts_as_chunky_bacon), ['default', 'alternate']
  end

  def test_load_no_plugins_when_config_plugins_is_empty_array
    @init.configuration.plugins = []
    assert_loaded_plugins [], ['default', 'alternate']   
  end
 
  def test_load_only_selected_plugins
    plugins = %w(stubby a)
    @init.configuration.plugins = plugins
    assert_loaded_plugins plugins, ['default', 'alternate']
  end
 
  def test_load_plugins_in_order
    plugins = %w(stubby acts_as_chunky_bacon a)
    @init.configuration.plugins = plugins
    assert_plugin_load_order plugins, ['default', 'alternate']
  end

  def test_raise_error_when_plugin_not_found
    @init.configuration.plugins = %w(this_plugin_does_not_exist)
    assert_raise(LoadError) { load_plugins(['default', 'alternate']) }
  end
  
  protected
    def assert_loaded_plugins(plugins, paths)
      assert_equal plugins.sort, load_plugins(paths).sort
    end
    
    def assert_plugin_load_order(plugins, paths)
      assert_equal plugins, load_plugins(paths)
    end

    def load_plugins(*paths)
      @init.configuration.plugin_paths = paths.flatten.map { |p| "#{File.dirname(__FILE__)}/fixtures/plugins/#{p}" }
      @init.load_plugins
      @init.loaded_plugins
    end
end
