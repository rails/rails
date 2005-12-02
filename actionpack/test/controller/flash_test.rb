require File.dirname(__FILE__) + '/../abstract_unit'

class FlashTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["that"] = "hello"
      render :inline => "hello"
    end

    def set_flash_now
      flash.now["that"] = "hello"
      flash.now["foo"] ||= "bar"
      flash.now["foo"] ||= "err"
      @flashy = flash.now["that"]
      @flash_copy = {}.update flash
      render :inline => "hello"
    end

    def attempt_to_use_flash_now
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render :inline => "hello"
    end

    def use_flash
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render :inline => "hello"
    end

    def use_flash_and_keep_it
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      silence_warnings { keep_flash }
      render :inline => "hello"
    end

    def rescue_action(e)
      raise unless ActionController::MissingTemplate === e
    end
  end

  def setup
    initialize_request_and_response
  end

  def test_flash
    @request.action = "set_flash"
    response = process_request

    @request.action = "use_flash"
    first_response = process_request
    assert_equal "hello", first_response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", first_response.template.assigns["flashy"]

    second_response = process_request
    assert_nil second_response.template.assigns["flash_copy"]["that"], "On second flash"
  end

  def test_keep_flash
    @request.action = "set_flash"
    response = process_request
    
    @request.action = "use_flash_and_keep_it"
    first_response = process_request
    assert_equal "hello", first_response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", first_response.template.assigns["flashy"]

    @request.action = "use_flash"
    second_response = process_request
    assert_equal "hello", second_response.template.assigns["flash_copy"]["that"], "On second flash"

    third_response = process_request
    assert_nil third_response.template.assigns["flash_copy"]["that"], "On third flash"
  end
  
  def test_flash_now
    @request.action = "set_flash_now"
    response = process_request
    assert_equal "hello", response.template.assigns["flash_copy"]["that"]
    assert_equal "bar"  , response.template.assigns["flash_copy"]["foo"]
    assert_equal "hello", response.template.assigns["flashy"]

    @request.action = "attempt_to_use_flash_now"
    first_response = process_request
    assert_nil first_response.template.assigns["flash_copy"]["that"]
    assert_nil first_response.template.assigns["flash_copy"]["foo"]
    assert_nil first_response.template.assigns["flashy"]
  end 
  
  private
    def initialize_request_and_response
      @request  = ActionController::TestRequest.new
      @response = ActionController::TestResponse.new
    end
  
    def process_request
      TestController.process(@request, @response)
    end
end
