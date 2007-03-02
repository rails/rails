$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'
require 'initializer'

# We need to set RAILS_ROOT if it isn't already set
RAILS_ROOT = '.' unless defined?(RAILS_ROOT)
class Test::Unit::TestCase
  def plugin_fixture_root_path
    File.join(File.dirname(__FILE__), 'fixtures', 'plugins')
  end
  
  def only_load_the_following_plugins!(plugins)
    @initializer.configuration.plugins = plugins
  end
end