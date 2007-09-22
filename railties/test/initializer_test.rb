require "#{File.dirname(__FILE__)}/abstract_unit"
require 'initializer'

class ConfigurationMock < Rails::Configuration
  attr_reader :environment_path

  def initialize(envpath)
    super()
    @environment_path = envpath
  end
end

class Initializer_load_environment_Test < Test::Unit::TestCase

  def test_load_environment_with_constant
    config = ConfigurationMock.new("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")
    assert_nil $initialize_test_set_from_env
    Rails::Initializer.run(:load_environment, config)
    assert_equal "success", $initialize_test_set_from_env
  ensure
    $initialize_test_set_from_env = nil
  end

end

class Initializer_after_initialize_with_blocks_environment_Test < Test::Unit::TestCase
  def setup
    config = ConfigurationMock.new("")
    config.after_initialize do
      $test_after_initialize_block1 = "success"
    end
    config.after_initialize do
      $test_after_initialize_block2 = "congratulations"
    end    
    assert_nil $test_after_initialize_block1
    assert_nil $test_after_initialize_block2    

    Rails::Initializer.run(:after_initialize, config)
  end
  
  def teardown
    $test_after_initialize_block1 = nil
    $test_after_initialize_block2 = nil    
  end

  def test_should_have_called_the_first_after_initialize_block
    assert_equal "success", $test_after_initialize_block1
  end
  
  def test_should_have_called_the_second_after_initialize_block
    assert_equal "congratulations", $test_after_initialize_block2
  end
end
  
class Initializer_after_initialize_with_no_block_environment_Test < Test::Unit::TestCase

  def setup
    config = ConfigurationMock.new("")
    config.after_initialize do
      $test_after_initialize_block1 = "success"
    end
    config.after_initialize # don't pass a block, this is what we're testing!
    config.after_initialize do
      $test_after_initialize_block2 = "congratulations"
    end    
    assert_nil $test_after_initialize_block1

    Rails::Initializer.run(:after_initialize, config)
  end

  def teardown
    $test_after_initialize_block1 = nil
    $test_after_initialize_block2 = nil    
  end

  def test_should_have_called_the_first_after_initialize_block
    assert_equal "success", $test_after_initialize_block1, "should still get set"
  end

  def test_should_have_called_the_second_after_initialize_block
    assert_equal "congratulations", $test_after_initialize_block2
  end

end
