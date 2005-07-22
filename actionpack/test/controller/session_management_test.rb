require File.dirname(__FILE__) + '/../abstract_unit'

class SessionManagementTest < Test::Unit::TestCase
  class SessionOffController < ActionController::Base
    session :off

    def show
      render_text "done"
    end

    def tell
      render_text "done"
    end
  end

  class TestController < ActionController::Base
    session :off, :only => :show
    session :session_secure => true, :except => :show

    def show
      render_text "done"
    end

    def tell
      render_text "done"
    end
  end

  def setup
    @request, @response = ActionController::TestRequest.new,
      ActionController::TestResponse.new
  end

  def test_session_off_globally
    @controller = SessionOffController.new
    get :show
    assert_equal false, @request.session_options
    get :tell
    assert_equal false, @request.session_options
  end

  def test_session_off_conditionally
    @controller = TestController.new
    get :show
    assert_equal false, @request.session_options
    get :tell
    assert_instance_of Hash, @request.session_options
    assert @request.session_options[:session_secure]
  end
end
