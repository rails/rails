require File.dirname(__FILE__) + '/../abstract_unit'

class VerificationTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    verify :only => :guarded_one, :params => "one",
           :redirect_to => { :action => "unguarded" }

    verify :only => :guarded_two, :params => %w( one two ),
           :redirect_to => { :action => "unguarded" }

    verify :only => :guarded_with_flash, :params => "one",
           :add_flash => { "notice" => "prereqs failed" },
           :redirect_to => { :action => "unguarded" }

    verify :only => :guarded_in_session, :session => "one",
           :redirect_to => { :action => "unguarded" }

    verify :only => [:multi_one, :multi_two], :session => %w( one two ),
           :redirect_to => { :action => "unguarded" }

    def guarded_one
      render_text "#{@params["one"]}"
    end

    def guarded_with_flash
      render_text "#{@params["one"]}"
    end

    def guarded_two
      render_text "#{@params["one"]}:#{@params["two"]}"
    end

    def guarded_in_session
      render_text "#{@session["one"]}"
    end

    def multi_one
      render_text "#{@session["one"]}:#{@session["two"]}"
    end

    def multi_two
      render_text "#{@session["two"]}:#{@session["one"]}"
    end

    def unguarded
      render_text "#{@params["one"]}"
    end
  end

  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_guarded_one_with_prereqs
    process "guarded_one", "one" => "here"
    assert_equal "here", @response.body
  end

  def test_guarded_one_without_prereqs
    process "guarded_one"
    assert_redirected_to :action => "unguarded"
  end

  def test_guarded_with_flash_with_prereqs
    process "guarded_with_flash", "one" => "here"
    assert_equal "here", @response.body
    assert_flash_empty
  end

  def test_guarded_with_flash_without_prereqs
    process "guarded_with_flash"
    assert_redirected_to :action => "unguarded"
    assert_flash_equal "prereqs failed", "notice"
  end

  def test_guarded_two_with_prereqs
    process "guarded_two", "one" => "here", "two" => "there"
    assert_equal "here:there", @response.body
  end

  def test_guarded_two_without_prereqs_one
    process "guarded_two", "two" => "there"
    assert_redirected_to :action => "unguarded"
  end

  def test_guarded_two_without_prereqs_two
    process "guarded_two", "one" => "here"
    assert_redirected_to :action => "unguarded"
  end

  def test_guarded_two_without_prereqs_both
    process "guarded_two"
    assert_redirected_to :action => "unguarded"
  end

  def test_unguarded_with_params
    process "unguarded", "one" => "here"
    assert_equal "here", @response.body
  end

  def test_unguarded_without_params
    process "unguarded"
    assert_equal "", @response.body
  end

  def test_guarded_in_session_with_prereqs
    process "guarded_in_session", {}, "one" => "here"
    assert_equal "here", @response.body
  end

  def test_guarded_in_session_without_prereqs
    process "guarded_in_session"
    assert_redirected_to :action => "unguarded"
  end

  def test_multi_one_with_prereqs
    process "multi_one", {}, "one" => "here", "two" => "there"
    assert_equal "here:there", @response.body
  end

  def test_multi_one_without_prereqs
    process "multi_one"
    assert_redirected_to :action => "unguarded"
  end

  def test_multi_two_with_prereqs
    process "multi_two", {}, "one" => "here", "two" => "there"
    assert_equal "there:here", @response.body
  end

  def test_multi_two_without_prereqs
    process "multi_two"
    assert_redirected_to :action => "unguarded"
  end
end
