require "#{File.dirname(__FILE__)}/abstract_unit"
require 'initializer'

class InitializerTest < Test::Unit::TestCase
  class ConfigurationMock < Rails::Configuration
    attr_reader :environment_path

    def initialize(envpath)
      super()
      @environment_path = envpath
    end
  end

  def test_load_environment_with_constant
    config = ConfigurationMock.new("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")
    assert_nil $initialize_test_set_from_env
    Rails::Initializer.run(:load_environment, config)
    assert_equal "success", $initialize_test_set_from_env
  ensure
    $initialize_test_set_from_env = nil
  end
end
