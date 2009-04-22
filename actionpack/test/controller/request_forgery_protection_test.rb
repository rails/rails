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
  
  def rescue_action(e) raise e end
end

# sample controllers
class RequestForgeryProtectionController < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => :index
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

  def test_should_not_allow_html_post_without_token
    @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
    assert_raise(ActionController::InvalidAuthenticityToken) { post :index, :format => :html }
  end
  
  def test_should_not_allow_html_put_without_token
    @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
    assert_raise(ActionController::InvalidAuthenticityToken) { put :index, :format => :html }
  end
  
  def test_should_not_allow_html_delete_without_token
    @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
    assert_raise(ActionController::InvalidAuthenticityToken) { delete :index, :format => :html }
  end

  def test_should_allow_api_formatted_post_without_token
    assert_nothing_raised do
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_without_token
    assert_nothing_raised do
      put :index, :format => 'xml'
    end
  end

  def test_should_allow_api_formatted_delete_without_token
    assert_nothing_raised do
      delete :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_post_sent_as_url_encoded_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_sent_as_url_encoded_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      put :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_delete_sent_as_url_encoded_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
      delete :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_post_sent_as_multipart_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      post :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_put_sent_as_multipart_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      put :index, :format => 'xml'
    end
  end

  def test_should_not_allow_api_formatted_delete_sent_as_multipart_form_without_token
    assert_raise(ActionController::InvalidAuthenticityToken) do
      @request.env['CONTENT_TYPE'] = Mime::MULTIPART_FORM.to_s
      delete :index, :format => 'xml'
    end
  end
  
  def test_should_allow_xhr_post_without_token
    assert_nothing_raised { xhr :post, :index }
  end
  
  def test_should_allow_xhr_put_without_token
    assert_nothing_raised { xhr :put, :index }
  end
  
  def test_should_allow_xhr_delete_without_token
    assert_nothing_raised { xhr :delete, :index }
  end
  
  def test_should_allow_xhr_post_with_encoded_form_content_type_without_token
    @request.env['CONTENT_TYPE'] = Mime::URL_ENCODED_FORM.to_s
    assert_nothing_raised { xhr :post, :index }
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

class RequestForgeryProtectionControllerTest < ActionController::TestCase
  include RequestForgeryProtectionTests
  def setup
    @controller = RequestForgeryProtectionController.new
    @request    = ActionController::TestRequest.new
    @request.format = :html
    @response   = ActionController::TestResponse.new
    @token      = "cf50faa3fe97702ca1ae"

    ActiveSupport::SecureRandom.stubs(:base64).returns(@token)
    ActionController::Base.request_forgery_protection_token = :authenticity_token
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
end
