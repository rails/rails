require 'abstract_unit'
require 'digest/sha1'
require "active_support/log_subscriber/test_helper"

# common controller actions
module RequestForgeryProtectionActions
  def index
    render :inline => "<%= form_tag('/') {} %>"
  end

  def show_button
    render :inline => "<%= button_to('New', '/') %>"
  end

  def external_form
    render :inline => "<%= form_tag('http://farfar.away/form', :authenticity_token => 'external_token') {} %>"
  end

  def external_form_without_protection
    render :inline => "<%= form_tag('http://farfar.away/form', :authenticity_token => false) {} %>"
  end

  def unsafe
    render :text => 'pwn'
  end

  def meta
    render :inline => "<%= csrf_meta_tags %>"
  end

  def external_form_for
    render :inline => "<%= form_for(:some_resource, :authenticity_token => 'external_token') {} %>"
  end

  def form_for_without_protection
    render :inline => "<%= form_for(:some_resource, :authenticity_token => false ) {} %>"
  end

  def form_for_remote
    render :inline => "<%= form_for(:some_resource, :remote => true ) {} %>"
  end

  def form_for_remote_with_token
    render :inline => "<%= form_for(:some_resource, :remote => true, :authenticity_token => true ) {} %>"
  end

  def form_for_with_token
    render :inline => "<%= form_for(:some_resource, :authenticity_token => true ) {} %>"
  end

  def form_for_remote_with_external_token
    render :inline => "<%= form_for(:some_resource, :remote => true, :authenticity_token => 'external_token') {} %>"
  end

  def rescue_action(e) raise e end
end

# sample controllers
class RequestForgeryProtectionControllerUsingResetSession < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => %w(index meta), :with => :reset_session
end

class RequestForgeryProtectionControllerUsingException < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery :only => %w(index meta), :with => :exception
end


class FreeCookieController < RequestForgeryProtectionControllerUsingResetSession
  self.allow_forgery_protection = false

  def index
    render :inline => "<%= form_tag('/') {} %>"
  end

  def show_button
    render :inline => "<%= button_to('New', '/') %>"
  end
end

class CustomAuthenticityParamController < RequestForgeryProtectionControllerUsingResetSession
  def form_authenticity_param
    'foobar'
  end
end

# common test methods
module RequestForgeryProtectionTests
  def setup
    @token      = "cf50faa3fe97702ca1ae"

    SecureRandom.stubs(:base64).returns(@token)
    ActionController::Base.request_forgery_protection_token = :custom_authenticity_token
  end

  def teardown
    ActionController::Base.request_forgery_protection_token = nil
  end

  def test_should_render_form_with_token_tag
    assert_not_blocked do
      get :index
    end
    assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', @token
  end

  def test_should_render_button_to_with_token_tag
    assert_not_blocked do
      get :show_button
    end
    assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', @token
  end

  def test_should_render_form_without_token_tag_if_remote
    assert_not_blocked do
      get :form_for_remote
    end
    assert_no_match(/authenticity_token/, response.body)
  end

  def test_should_render_form_with_token_tag_if_remote_and_embedding_token_is_on
    original = ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms
    begin
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = true
      assert_not_blocked do
        get :form_for_remote
      end
      assert_match(/authenticity_token/, response.body)
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
  end

  def test_should_render_form_with_token_tag_if_remote_and_external_authenticity_token_requested_and_embedding_is_on
    original = ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms
    begin
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = true
      assert_not_blocked do
        get :form_for_remote_with_external_token
      end
      assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
  end

  def test_should_render_form_with_token_tag_if_remote_and_external_authenticity_token_requested
    assert_not_blocked do
      get :form_for_remote_with_external_token
    end
    assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
  end

  def test_should_render_form_with_token_tag_if_remote_and_authenticity_token_requested
    assert_not_blocked do
      get :form_for_remote_with_token
    end
    assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', @token
  end

  def test_should_render_form_with_token_tag_with_authenticity_token_requested
    assert_not_blocked do
      get :form_for_with_token
    end
    assert_select 'form>div>input[name=?][value=?]', 'custom_authenticity_token', @token
  end

  def test_should_allow_get
    assert_not_blocked { get :index }
  end

  def test_should_allow_head
    assert_not_blocked { head :index }
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

  def test_should_not_allow_patch_without_token
    assert_blocked { patch :index }
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
    assert_not_blocked { post :index, :custom_authenticity_token => @token }
  end

  def test_should_allow_patch_with_token
    assert_not_blocked { patch :index, :custom_authenticity_token => @token }
  end

  def test_should_allow_put_with_token
    assert_not_blocked { put :index, :custom_authenticity_token => @token }
  end

  def test_should_allow_delete_with_token
    assert_not_blocked { delete :index, :custom_authenticity_token => @token }
  end

  def test_should_allow_post_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { post :index }
  end

  def test_should_allow_delete_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { delete :index }
  end

  def test_should_allow_patch_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { patch :index }
  end

  def test_should_allow_put_with_token_in_header
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { put :index }
  end

  def test_should_warn_on_missing_csrf_token
    old_logger = ActionController::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    ActionController::Base.logger = logger

    begin
      assert_blocked { post :index }

      assert_equal 1, logger.logged(:warn).size
      assert_match(/CSRF token authenticity/, logger.logged(:warn).last)
    ensure
      ActionController::Base.logger = old_logger
    end
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

class RequestForgeryProtectionControllerUsingResetSessionTest < ActionController::TestCase
  include RequestForgeryProtectionTests

  setup do
    ActionController::Base.request_forgery_protection_token = :custom_authenticity_token
  end

  teardown do
    ActionController::Base.request_forgery_protection_token = nil
  end

  test 'should emit a csrf-param meta tag and a csrf-token meta tag' do
    SecureRandom.stubs(:base64).returns(@token + '<=?')
    get :meta
    assert_select 'meta[name=?][content=?]', 'csrf-param', 'custom_authenticity_token'
    assert_select 'meta[name=?][content=?]', 'csrf-token', 'cf50faa3fe97702ca1ae&lt;=?'
  end
end

class RequestForgeryProtectionControllerUsingExceptionTest < ActionController::TestCase
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

    SecureRandom.stubs(:base64).returns(@token)
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
    [:post, :patch, :put, :delete].each do |method|
      assert_nothing_raised { send(method, :index)}
    end
  end

  test 'should not emit a csrf-token meta tag' do
    get :meta
    assert @response.body.blank?
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
