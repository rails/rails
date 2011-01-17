require 'abstract_unit'
require 'digest/sha1'

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

# common controller actions
module RequestForgeryProtectionActions
  def index
    render :inline => "<%= form_tag('/') {} %>"
  end
  
  def show_button
    render :inline => "<%= button_to('New', '/') {} %>"
  end
  
  def remote_form
    render :inline => "<% form_remote_tag(:url => '/') {} %>"
  end

  def unsafe
    render :text => 'pwn'
  end

  def meta
    render :inline => "<%= csrf_meta_tag %>"
  end

  def rescue_action(e) raise e end
end

# sample controllers
class RequestForgeryProtectionController < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => :index
end

class RequestForgeryProtectionControllerUsingOldBehaviour < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => %w(index meta)

  def handle_unverified_request
    raise(ActionController::InvalidAuthenticityToken)
  end
end


class FreeCookieController < RequestForgeryProtectionController
  self.allow_forgery_protection = false
  
  def index
    render :inline => "<%= form_tag('/') {} %>"
  end
  
  def show_button
    render :inline => "<%= button_to('New', '/') {} %>"
  end
end

class CustomAuthenticityParamController < RequestForgeryProtectionController
  def form_authenticity_param
    'foobar'
  end
end


# common test methods

module RequestForgeryProtectionTests
  def setup
    @token      = "cf50faa3fe97702ca1ae"

    ActiveSupport::SecureRandom.stubs(:base64).returns(@token)
    ActionController::Base.request_forgery_protection_token = :authenticity_token
  end
  
  
  def test_should_render_form_with_token_tag
    assert_not_blocked do
      get :index
    end
    assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token
  end

  def test_should_render_button_to_with_token_tag
    assert_not_blocked do
      get :show_button
    end
    assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token
  end

  def test_should_allow_get
    assert_not_blocked { get :index }
  end

  def test_should_allow_post_without_token_on_unsafe_action
    assert_not_blocked { post :unsafe }
  end

  def test_should_not_allow_post_without_token
    assert_blocked { post :index }
  end

  def test_should_not_allow_post_without_token_irrespective_of_format
    assert_blocked { post :index, :format=>'xml' }
  end

  def test_should_not_allow_put_without_token
    assert_blocked { put :index }
  end

  def test_should_not_allow_delete_without_token
    assert_blocked { delete :index }
  end

  def test_should_not_allow_xhr_post_without_token
    assert_blocked { xhr :post, :index }
  end

  def test_should_allow_post_with_token
    assert_not_blocked { post :index, :authenticity_token => @token }
  end
  
  def test_should_allow_put_with_token
    assert_not_blocked { put :index, :authenticity_token => @token }
  end
  
  def test_should_allow_delete_with_token
    assert_not_blocked { delete :index, :authenticity_token => @token }
  end
  
  def test_should_allow_post_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { post :index }
  end

  def test_should_allow_delete_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { delete :index }
  end
  
  def test_should_allow_put_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { put :index }
  end

  def assert_blocked
    session[:something_like_user_id] = 1
    yield
    assert_nil session[:something_like_user_id], "session values are still present"
    assert_response :success
  end
  
  def assert_not_blocked
    assert_nothing_raised { yield }
    assert_response :success
  end
end

# OK let's get our test on

class RequestForgeryProtectionControllerTest < ActionController::TestCase
  include RequestForgeryProtectionTests

  test 'should emit a csrf-token meta tag' do
    ActiveSupport::SecureRandom.stubs(:base64).returns(@token + '<=?')
    get :meta
    assert_equal %(<meta name="csrf-param" content="authenticity_token"/>\n<meta name="csrf-token" content="cf50faa3fe97702ca1ae&lt;=?"/>), @response.body
  end
end

class RequestForgeryProtectionControllerUsingOldBehaviourTest < ActionController::TestCase
  include RequestForgeryProtectionTests
  def assert_blocked
    assert_raises(ActionController::InvalidAuthenticityToken) do
      yield
    end
  end
end

class FreeCookieControllerTest < ActionController::TestCase
  def setup
    @controller = FreeCookieController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @token      = "cf50faa3fe97702ca1ae"

    ActiveSupport::SecureRandom.stubs(:base64).returns(@token)
  end
  
  def test_should_not_render_form_with_token_tag
    get :index
    assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token, false
  end
  
  def test_should_not_render_button_to_with_token_tag
    get :show_button
    assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token, false
  end
  
  def test_should_allow_all_methods_without_token
    [:post, :put, :delete].each do |method|
      assert_nothing_raised { send(method, :index)}
    end
  end

  test 'should not emit a csrf-token meta tag' do
    get :meta
    assert_blank @response.body
  end
end





class CustomAuthenticityParamControllerTest < ActionController::TestCase
  def setup
    ActionController::Base.request_forgery_protection_token = :custom_token_name
    super
  end

  def teardown
    ActionController::Base.request_forgery_protection_token = :authenticity_token
    super
  end

  def test_should_allow_custom_token
    post :index, :custom_token_name => 'foobar'
    assert_response :ok
  end
end
