require 'abstract_unit'

class SessionFixationTest < ActionController::IntegrationTest
  class TestController < ActionController::Base
    session :session_key => '_myapp_session_id',
            :secret => CGI::Session.generate_unique_id,
            :except => :default_session_key

    session :cookie_only => false,
            :only => :allow_session_fixation

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
    with_test_route_set do
      assert_nothing_raised do
        get '/custom_session_key', :id => "1"
      end
      assert_equal 'custom_session_key: 1', @controller.response.body
      assert_not_nil @controller.session
    end
  end

  def test_should_catch_session_fixation_attempt
    with_test_route_set do
      assert_raises(ActionController::RackRequest::SessionFixationAttempt) do
        get '/custom_session_key', :_myapp_session_id => "42"
      end
      assert_nil @controller.session
    end
  end

  def test_should_not_catch_session_fixation_attempt_when_cookie_only_setting_is_disabled
    with_test_route_set do
      assert_nothing_raised do
        get '/allow_session_fixation', :_myapp_session_id => "42"
      end
      assert !@controller.response.body.blank?
      assert_not_nil @controller.session
    end
  end

  def test_should_catch_session_fixation_attempt_with_default_session_key
    # using the default session_key is not possible with cookie store
    ActionController::Base.session_store = :p_store

    with_test_route_set do
      assert_raises ActionController::RackRequest::SessionFixationAttempt do
        get '/default_session_key', :_session_id => "42"
      end
      assert_nil @controller.response
      assert_nil @controller.session
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do |map|
          map.with_options :controller => "session_fixation_test/test" do |c|
            c.connect "/:action"
          end
        end
        yield
      end
    end
end
