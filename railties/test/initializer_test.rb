$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'
require 'initializer'

class InitializerTest < Test::Unit::TestCase
  class ConfigurationMock < Rails::Configuration
    def initialize(envpath)
      super()
      @envpath = envpath
    end
    
    def environment_path
      @envpath
    end
  end

  def setup
    Object.const_set(:RAILS_ROOT, "") rescue nil
  end
  
  def teardown
    Object.remove_const(:RAILS_ROOT) rescue nil
  end
  
  def test_load_environment_with_constant
    config = ConfigurationMock.new("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")
    Rails::Initializer.run(:load_environment, config)
    assert Object.const_defined?(:SET_FROM_ENV)
    assert_equal "success", SET_FROM_ENV
  ensure
    Object.remove_const(:SET_FROM_ENV) rescue nil
  end
end