require File.dirname(__FILE__) + '/../abstract_unit'

class TestTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["test"] = ">#{flash["test"]}<"
    end
  end

  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_process_without_flash
    process :set_flash
    assert_flash_equal "><", "test"
  end

  def test_process_with_flash
    process :set_flash, nil, nil, { "test" => "value" }
    assert_flash_equal ">value<", "test"
  end
end
