require 'abstract_unit'


class SessionFixationTest < Test::Unit::TestCase
  class MockCGI < CGI #:nodoc:
    attr_accessor :stdoutput, :env_table

    def initialize(env, data = '')
      self.env_table = env
      self.stdoutput = StringIO.new
      super(nil, StringIO.new(data))
    end
  end

  class TestController < ActionController::Base
    session :session_key => '_myapp_session_id', :secret => CGI::Session.generate_unique_id, :except => :default_session_key
    session :cookie_only => false, :only => :allow_session_fixation

    def default_session_key
      render :text => "default_session_key"
    end

    def custom_session_key
      render :text => "custom_session_key: #{params[:id]}"
    end

    def allow_session_fixation
      render :text => "allow_session_fixation"
    end

    def rescue_action(e) raise end
  end

  def setup
    @controller = TestController.new
  end

  def test_should_be_able_to_make_a_successful_request
    cgi = mock_cgi_for_request_to(:custom_session_key, :id => 1)

    assert_nothing_raised do
      @controller.send(:process, ActionController::CgiRequest.new(cgi, {}), ActionController::CgiResponse.new(cgi))
    end
    assert_equal 'custom_session_key: 1', @controller.response.body
    assert_not_nil @controller.session
  end

  def test_should_catch_session_fixation_attempt
    cgi = mock_cgi_for_request_to(:custom_session_key, :_myapp_session_id => 42)

    assert_raises ActionController::CgiRequest::SessionFixationAttempt do
      @controller.send(:process, ActionController::CgiRequest.new(cgi, {}), ActionController::CgiResponse.new(cgi))
    end
    assert_nil @controller.session
  end

  def test_should_not_catch_session_fixation_attempt_when_cookie_only_setting_is_disabled
    cgi = mock_cgi_for_request_to(:allow_session_fixation, :_myapp_session_id => 42)

    assert_nothing_raised do
      @controller.send(:process, ActionController::CgiRequest.new(cgi, {}), ActionController::CgiResponse.new(cgi))
    end
    assert ! @controller.response.body.blank?
    assert_not_nil @controller.session
  end

  def test_should_catch_session_fixation_attempt_with_default_session_key
    ActionController::Base.session_store = :p_store # using the default session_key is not possible with cookie store
    cgi = mock_cgi_for_request_to(:default_session_key, :_session_id => 42)

    assert_raises ActionController::CgiRequest::SessionFixationAttempt do
      @controller.send(:process, ActionController::CgiRequest.new(cgi, {}), ActionController::CgiResponse.new(cgi))
    end
    assert @controller.response.body.blank?
    assert_nil @controller.session
  end

private

  def mock_cgi_for_request_to(action, params = {})
    MockCGI.new({
      "REQUEST_METHOD" => "GET",
      "QUERY_STRING"   => "action=#{action}&#{params.to_query}",
      "REQUEST_URI"    => "/",
      "SERVER_PORT"    => "80",
      "HTTP_HOST"      => "testdomain.com" }, '')
  end

end
