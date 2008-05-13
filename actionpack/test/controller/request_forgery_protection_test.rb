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

class FreeCookieController < CsrfCookieMonsterController
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

  def test_should_not_allow_post_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { post :index }
  end

  def test_should_not_allow_put_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { put :index }
  end

  def test_should_not_allow_delete_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { delete :index }
  end

  def test_should_not_allow_api_formatted_post_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      put :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_delete_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      delete :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_post_sent_as_url_encoded_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_sent_as_url_encoded_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      put :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_delete_sent_as_url_encoded_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      delete :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_post_sent_as_multipart_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_sent_as_multipart_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      put :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_delete_sent_as_multipart_form_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      delete :index, :format => 'xml'
    end
  end

  def test_should_not_allow_xhr_post_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { xhr :post, :index }
  end
  
  def test_should_not_allow_xhr_put_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { xhr :put, :index }
  end
  
  def test_should_not_allow_xhr_delete_without_token
    assert_raises(ActionController::InvalidAuthenticityToken) { xhr :delete, :index }
  end
  
  def test_should_allow_post_with_token
    post :index, :authenticity_token => @token
    assert_response :success
  end
  
  def test_should_allow_put_with_token
    put :index, :authenticity_token => @token
    assert_response :success
  end
  
  def test_should_allow_delete_with_token
    delete :index, :authenticity_token => @token
    assert_response :success
  end
  
  def test_should_allow_post_with_xml
    @request.env['CONTENT_TYPE'] = Mime::XML.to_s
    post :index, :format => 'xml'
    assert_response :success
  end
  
  def test_should_allow_put_with_xml
    @request.env['CONTENT_TYPE'] = Mime::XML.to_s
    put :index, :format => 'xml'
    assert_response :success
  end
  
  def test_should_allow_delete_with_xml
    @request.env['CONTENT_TYPE'] = Mime::XML.to_s
    delete :index, :format => 'xml'
    assert_response :success
  end
end

# OK let's get our test on

class RequestForgeryProtectionControllerTest < Test::Unit::TestCase
  include RequestForgeryProtectionTests
  def setup
    @controller = RequestForgeryProtectionController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    class << @request.session
      def session_id() '123' end
    end
    @token = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), 'abc', '123')
    ActionController::Base.request_forgery_protection_token = :authenticity_token
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
end

class SessionOffControllerTest < Test::Unit::TestCase
  def setup
    @controller = SessionOffController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @token      = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), 'abc', '123')
  end

  def test_should_raise_correct_exception
    @request.session = {} # session(:off) doesn't appear to work with controller tests
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post :index, :authenticity_token => @token
    end
  end
end
