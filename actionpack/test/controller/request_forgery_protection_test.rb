require 'abstract_unit'
require 'digest/sha1'

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

# simulates cookie session store
class FakeSessionDbMan
  def self.generate_digest(data)
    Digest::SHA1.hexdigest("secure")
  end
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
  protect_from_forgery :only => :index, :secret => 'abc'
end

class RequestForgeryProtectionWithoutSecretController < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery
end

# no token is given, assume the cookie store is used
class CsrfCookieMonsterController < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => :index
end

# sessions are turned off
class SessionOffController < ActionController::Base
  protect_from_forgery :secret => 'foobar'
  session :off
  def rescue_action(e) raise e end
  include RequestForgeryProtectionActions
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

# common test methods

module RequestForgeryProtectionTests
  def teardown
    ActionController::Base.request_forgery_protection_token = nil
  end
  

  def test_should_render_form_with_token_tag
     get :index
     assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token
   end

   def test_should_render_button_to_with_token_tag
     get :show_button
     assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token
   end

   def test_should_render_remote_form_with_only_one_token_parameter
     get :remote_form
     assert_equal 1, @response.body.scan(@token).size
   end

   def test_should_allow_get
     get :index
     assert_response :success
   end

   def test_should_allow_post_without_token_on_unsafe_action
     post :unsafe
     assert_response :success
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
    @request.session[:something_like_user_id] = 1
    yield
    assert_nil @request.session[:something_like_user_id], "session values are still present"
    assert_response :success
  end
  
  def assert_not_blocked
    assert_nothing_raised { yield }
    assert_response :success
  end
end

# OK let's get our test on

class RequestForgeryProtectionControllerTest < Test::Unit::TestCase
  include RequestForgeryProtectionTests
  def setup
    @controller = RequestForgeryProtectionController.new
    @request    = ActionController::TestRequest.new
    @request.format = :html
    @response   = ActionController::TestResponse.new
    class << @request.session
      def session_id() '123' end
    end
    @token = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), 'abc', '123')
    ActionController::Base.request_forgery_protection_token = :authenticity_token
  end

  def test_should_emit_meta_tag 
    get :meta
    assert_equal %(<meta name="csrf-param" content="authenticity_token"/>\n<meta name="csrf-token" content="#{@token}"/>), @response.body
  end
end

class RequestForgeryProtectionWithoutSecretControllerTest < Test::Unit::TestCase
  def setup
    @controller = RequestForgeryProtectionWithoutSecretController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    class << @request.session
      def session_id() '123' end
    end
    @token = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), 'abc', '123')
    ActionController::Base.request_forgery_protection_token = :authenticity_token
  end
  
   def test_should_raise_error_without_secret
     assert_raises ActionController::InvalidAuthenticityToken do
       get :index
     end
   end
end

class CsrfCookieMonsterControllerTest < Test::Unit::TestCase
  include RequestForgeryProtectionTests
  def setup
    @controller = CsrfCookieMonsterController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    class << @request.session
      attr_accessor :dbman
    end
    # simulate a cookie session store
    @request.session.dbman = FakeSessionDbMan
    @token = Digest::SHA1.hexdigest("secure")
    ActionController::Base.request_forgery_protection_token = :authenticity_token
  end
end

class FreeCookieControllerTest < Test::Unit::TestCase
  def setup
    @controller = FreeCookieController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @token      = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), 'abc', '123')
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

  def test_should_not_emit_meta_tag 
    get :meta
    assert @response.body.blank?, "Response body should be blank"
  end
end
