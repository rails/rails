require 'abstract_unit'

class FlashTest < ActionController::TestCase
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
      flash.keep
      render :inline => "hello"
    end
    
    def use_flash_and_update_it
      flash.update("this" => "hello again")
      @flash_copy = {}.update flash
      render :inline => "hello"
    end

    def use_flash_after_reset_session
      flash["that"] = "hello"
      @flashy_that = flash["that"]
      reset_session
      @flashy_that_reset = flash["that"]
      flash["this"] = "good-bye"
      @flashy_this = flash["this"]
      render :inline => "hello"
    end

    def rescue_action(e)
      raise unless ActionView::MissingTemplate === e
    end

    # methods for test_sweep_after_halted_filter_chain
    before_filter :halt_and_redir, :only => "filter_halting_action"

    def std_action
      @flash_copy = {}.update(flash)
    end

    def filter_halting_action
      @flash_copy = {}.update(flash)
    end

    def halt_and_redir
      flash["foo"] = "bar"
      redirect_to :action => "std_action"
      @flash_copy = {}.update(flash)
    end
  end

  tests TestController

  def test_flash
    get :set_flash

    get :use_flash
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :use_flash
    assert_nil @response.template.assigns["flash_copy"]["that"], "On second flash"
  end

  def test_keep_flash
    get :set_flash
    
    get :use_flash_and_keep_it
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :use_flash
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"], "On second flash"

    get :use_flash
    assert_nil @response.template.assigns["flash_copy"]["that"], "On third flash"
  end
  
  def test_flash_now
    get :set_flash_now
    assert_equal "hello", @response.template.assigns["flash_copy"]["that"]
    assert_equal "bar"  , @response.template.assigns["flash_copy"]["foo"]
    assert_equal "hello", @response.template.assigns["flashy"]

    get :attempt_to_use_flash_now
    assert_nil @response.template.assigns["flash_copy"]["that"]
    assert_nil @response.template.assigns["flash_copy"]["foo"]
    assert_nil @response.template.assigns["flashy"]
  end 
  
  def test_update_flash
    get :set_flash
    get :use_flash_and_update_it
    assert_equal "hello",       @response.template.assigns["flash_copy"]["that"]
    assert_equal "hello again", @response.template.assigns["flash_copy"]["this"]
    get :use_flash
    assert_nil                  @response.template.assigns["flash_copy"]["that"], "On second flash"
    assert_equal "hello again", @response.template.assigns["flash_copy"]["this"], "On second flash"
  end

  def test_flash_after_reset_session
    get :use_flash_after_reset_session
    assert_equal "hello",    @response.template.assigns["flashy_that"]
    assert_equal "good-bye", @response.template.assigns["flashy_this"]
    assert_nil   @response.template.assigns["flashy_that_reset"]
  end 

  def test_sweep_after_halted_filter_chain
    get :std_action
    assert_nil @response.template.assigns["flash_copy"]["foo"]
    get :filter_halting_action
    assert_equal "bar", @response.template.assigns["flash_copy"]["foo"]
    get :std_action # follow redirection
    assert_equal "bar", @response.template.assigns["flash_copy"]["foo"]
    get :std_action
    assert_nil @response.template.assigns["flash_copy"]["foo"]
  end

  def test_does_not_set_the_session_if_the_flash_is_empty
    get :std_action
    assert_nil session["flash"]
  end
end
