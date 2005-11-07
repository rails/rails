$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'
require 'initializer'

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
    expected = Set.new(['stubby'])

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

  protected
    def assert_loaded_plugins(plugins, path)
      assert_equal Set.new(plugins), load_plugins(path)
    end

    def load_plugins(*paths)
      @init.configuration.plugin_paths = paths.flatten.map { |p| "#{File.dirname(__FILE__)}/fixtures/plugins/#{p}" }
      @init.load_plugins
      @init.loaded_plugins
    end
end
