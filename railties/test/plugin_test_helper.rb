$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'
require 'initializer'
require File.join(File.dirname(__FILE__), 'abstract_unit')

# We need to set RAILS_ROOT if it isn't already set
RAILS_ROOT = '.' unless defined?(RAILS_ROOT)

class Test::Unit::TestCase
  private  
    def plugin_fixture_root_path
      File.join(File.dirname(__FILE__), 'fixtures', 'plugins')
    end
  
    def only_load_the_following_plugins!(plugins)
      @initializer.configuration.plugins = plugins
    end
  
    def plugin_fixture_path(path)
      File.join(plugin_fixture_root_path, path)
    end
    
    def assert_plugins(list_of_names, array_of_plugins, message=nil)
      assert_equal list_of_names.map(&:to_s), array_of_plugins.map(&:name), message
    end    
end