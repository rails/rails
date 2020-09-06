# frozen_string_literal: true

require 'abstract_unit'
require 'active_support/log_subscriber/test_helper'
require 'active_support/messages/rotation_configuration'

# common controller actions
module RequestForgeryProtectionActions
  def index
    render inline: "<%= form_tag('/') {} %>"
  end

  def show_button
    render inline: "<%= button_to('New', '/') %>"
  end

  def unsafe
    render plain: 'pwn'
  end

  def meta
    render inline: '<%= csrf_meta_tags %>'
  end

  def form_for_remote
    render inline: '<%= form_for(:some_resource, :remote => true ) {} %>'
  end

  def form_for_remote_with_token
    render inline: '<%= form_for(:some_resource, :remote => true, :authenticity_token => true ) {} %>'
  end

  def form_for_with_token
    render inline: '<%= form_for(:some_resource, :authenticity_token => true ) {} %>'
  end

  def form_for_remote_with_external_token
    render inline: "<%= form_for(:some_resource, :remote => true, :authenticity_token => 'external_token') {} %>"
  end

  def form_with_remote
    render inline: '<%= form_with(scope: :some_resource) {} %>'
  end

  def form_with_remote_with_token
    render inline: '<%= form_with(scope: :some_resource, authenticity_token: true) {} %>'
  end

  def form_with_local_with_token
    render inline: '<%= form_with(scope: :some_resource, local: true, authenticity_token: true) {} %>'
  end

  def form_with_remote_with_external_token
    render inline: "<%= form_with(scope: :some_resource, authenticity_token: 'external_token') {} %>"
  end

  def same_origin_js
    render js: 'foo();'
  end

  def negotiate_same_origin
    respond_to do |format|
      format.js { same_origin_js }
    end
  end

  def cross_origin_js
    same_origin_js
  end

  def negotiate_cross_origin
    negotiate_same_origin
  end
end

# sample controllers
class RequestForgeryProtectionControllerUsingResetSession < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery only: %w(index meta same_origin_js negotiate_same_origin), with: :reset_session
end

class RequestForgeryProtectionControllerUsingException < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery only: %w(index meta same_origin_js negotiate_same_origin), with: :exception
end

class RequestForgeryProtectionControllerUsingNullSession < ActionController::Base
  protect_from_forgery with: :null_session

  def signed
    cookies.signed[:foo] = 'bar'
    head :ok
  end

  def encrypted
    cookies.encrypted[:foo] = 'bar'
    head :ok
  end

  def try_to_reset_session
    reset_session
    head :ok
  end
end

class PrependProtectForgeryBaseController < ActionController::Base
  before_action :custom_action
  attr_accessor :called_callbacks

  def index
    render inline: 'OK'
  end

  private
    def add_called_callback(name)
      @called_callbacks ||= []
      @called_callbacks << name
    end

    def custom_action
      add_called_callback('custom_action')
    end

    def verify_authenticity_token
      add_called_callback('verify_authenticity_token')
    end
end

class FreeCookieController < RequestForgeryProtectionControllerUsingResetSession
  self.allow_forgery_protection = false

  def index
    render inline: "<%= form_tag('/') {} %>"
  end

  def show_button
    render inline: "<%= button_to('New', '/') %>"
  end
end

class CustomAuthenticityParamController < RequestForgeryProtectionControllerUsingResetSession
  def form_authenticity_param
    'foobar'
  end
end

class PerFormTokensController < ActionController::Base
  protect_from_forgery with: :exception
  self.per_form_csrf_tokens = true

  def index
    render inline: "<%= form_tag (params[:form_path] || '/per_form_tokens/post_one'), method: params[:form_method] %>"
  end

  def button_to
    render inline: "<%= button_to 'Button', (params[:form_path] || '/per_form_tokens/post_one'), method: params[:form_method] %>"
  end

  def post_one
    render plain: ''
  end

  def post_two
    render plain: ''
  end
end

class SkipProtectionController < ActionController::Base
  include RequestForgeryProtectionActions
  protect_from_forgery with: :exception
  skip_forgery_protection if: :skip_requested
  attr_accessor :skip_requested
end

# common test methods
module RequestForgeryProtectionTests
  def setup
    @old_urlsafe_csrf_tokens = ActionController::Base.urlsafe_csrf_tokens
    ActionController::Base.urlsafe_csrf_tokens = true
    @token = Base64.urlsafe_encode64('railstestrailstestrailstestrails')
    @old_request_forgery_protection_token = ActionController::Base.request_forgery_protection_token
    ActionController::Base.request_forgery_protection_token = :custom_authenticity_token
  end

  def teardown
    ActionController::Base.urlsafe_csrf_tokens = @old_urlsafe_csrf_tokens
    ActionController::Base.request_forgery_protection_token = @old_request_forgery_protection_token
  end

  def test_should_render_form_with_token_tag
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :index
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
  end

  def test_should_render_button_to_with_token_tag
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :show_button
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
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
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
  end

  def test_should_render_form_with_token_tag_if_remote_and_external_authenticity_token_requested
    assert_not_blocked do
      get :form_for_remote_with_external_token
    end
    assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
  end

  def test_should_render_form_with_token_tag_if_remote_and_authenticity_token_requested
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :form_for_remote_with_token
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
  end

  def test_should_render_form_with_token_tag_with_authenticity_token_requested
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :form_for_with_token
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
  end

  def test_should_render_form_with_with_token_tag_if_remote
    assert_not_blocked do
      get :form_with_remote
    end
    assert_match(/authenticity_token/, response.body)
  end

  def test_should_render_form_with_without_token_tag_if_remote_and_embedding_token_is_off
    original = ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms
    begin
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = false
      assert_not_blocked do
        get :form_with_remote
      end
      assert_no_match(/authenticity_token/, response.body)
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
  end

  def test_should_render_form_with_with_token_tag_if_remote_and_external_authenticity_token_requested_and_embedding_is_on
    original = ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms
    begin
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = true
      assert_not_blocked do
        get :form_with_remote_with_external_token
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
  end

  def test_should_render_form_with_with_token_tag_if_remote_and_external_authenticity_token_requested
    assert_not_blocked do
      get :form_with_remote_with_external_token
    end
    assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', 'external_token'
  end

  def test_should_render_form_with_with_token_tag_if_remote_and_authenticity_token_requested
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :form_with_remote_with_token
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
  end

  def test_should_render_form_with_with_token_tag_with_authenticity_token_requested
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked do
        get :form_with_local_with_token
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    end
  end

  def test_should_render_form_with_with_token_tag_if_remote_and_embedding_token_is_on
    original = ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms
    begin
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = true

      @controller.stub :form_authenticity_token, @token do
        assert_not_blocked do
          get :form_with_remote
        end
      end
      assert_select 'form>input[name=?][value=?]', 'custom_authenticity_token', @token
    ensure
      ActionView::Helpers::FormTagHelper.embed_authenticity_token_in_remote_forms = original
    end
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
    assert_blocked { post :index, format: 'xml' }
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
    assert_blocked { post :index, xhr: true }
  end

  def test_should_allow_post_with_token
    session[:_csrf_token] = @token
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked { post :index, params: { custom_authenticity_token: @token } }
    end
  end

  def test_should_allow_post_with_strict_encoded_token
    token_length = (ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH * 4.0 / 3).ceil
    token_including_url_unsafe_chars = '+/'.ljust(token_length, 'A')
    session[:_csrf_token] = token_including_url_unsafe_chars
    @controller.stub :form_authenticity_token, token_including_url_unsafe_chars do
      assert_not_blocked { post :index, params: { custom_authenticity_token: token_including_url_unsafe_chars } }
    end
  end

  def test_should_allow_post_with_urlsafe_token_when_migrating
    config_before = ActionController::Base.urlsafe_csrf_tokens
    ActionController::Base.urlsafe_csrf_tokens = false
    token_length = (ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH * 4.0 / 3).ceil
    token_including_url_safe_chars = '-_'.ljust(token_length, 'A')
    session[:_csrf_token] = token_including_url_safe_chars
    @controller.stub :form_authenticity_token, token_including_url_safe_chars do
      assert_not_blocked { post :index, params: { custom_authenticity_token: token_including_url_safe_chars } }
    end
  ensure
    ActionController::Base.urlsafe_csrf_tokens = config_before
  end

  def test_should_allow_patch_with_token
    session[:_csrf_token] = @token
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked { patch :index, params: { custom_authenticity_token: @token } }
    end
  end

  def test_should_allow_put_with_token
    session[:_csrf_token] = @token
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked { put :index, params: { custom_authenticity_token: @token } }
    end
  end

  def test_should_allow_delete_with_token
    session[:_csrf_token] = @token
    @controller.stub :form_authenticity_token, @token do
      assert_not_blocked { delete :index, params: { custom_authenticity_token: @token } }
    end
  end

  def test_should_allow_post_with_token_in_header
    session[:_csrf_token] = @token
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { post :index }
  end

  def test_should_allow_delete_with_token_in_header
    session[:_csrf_token] = @token
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { delete :index }
  end

  def test_should_allow_patch_with_token_in_header
    session[:_csrf_token] = @token
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { patch :index }
  end

  def test_should_allow_put_with_token_in_header
    session[:_csrf_token] = @token
    @request.env['HTTP_X_CSRF_TOKEN'] = @token
    assert_not_blocked { put :index }
  end

  def test_should_allow_post_with_origin_checking_and_correct_origin
    forgery_protection_origin_check do
      session[:_csrf_token] = @token
      @controller.stub :form_authenticity_token, @token do
        assert_not_blocked do
          @request.set_header 'HTTP_ORIGIN', 'http://test.host'
          post :index, params: { custom_authenticity_token: @token }
        end
      end
    end
  end

  def test_should_allow_post_with_origin_checking_and_no_origin
    forgery_protection_origin_check do
      session[:_csrf_token] = @token
      @controller.stub :form_authenticity_token, @token do
        assert_not_blocked do
          post :index, params: { custom_authenticity_token: @token }
        end
      end
    end
  end

  def test_should_raise_for_post_with_null_origin
    forgery_protection_origin_check do
      session[:_csrf_token] = @token
      @controller.stub :form_authenticity_token, @token do
        exception = assert_raises(ActionController::InvalidAuthenticityToken) do
          @request.set_header 'HTTP_ORIGIN', 'null'
          post :index, params: { custom_authenticity_token: @token }
        end
        assert_match "The browser returned a 'null' origin for a request", exception.message
      end
    end
  end

  def test_should_block_post_with_origin_checking_and_wrong_origin
    old_logger = ActionController::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    ActionController::Base.logger = logger

    forgery_protection_origin_check do
      session[:_csrf_token] = @token
      @controller.stub :form_authenticity_token, @token do
        assert_blocked do
          @request.set_header 'HTTP_ORIGIN', 'http://bad.host'
          post :index, params: { custom_authenticity_token: @token }
        end
      end
    end

    assert_match(
      "HTTP Origin header (http://bad.host) didn't match request.base_url (http://test.host)",
      logger.logged(:warn).last
    )
  ensure
    ActionController::Base.logger = old_logger
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

  def test_should_not_warn_if_csrf_logging_disabled
    old_logger = ActionController::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    ActionController::Base.logger = logger
    ActionController::Base.log_warning_on_csrf_failure = false

    begin
      assert_blocked { post :index }

      assert_equal 0, logger.logged(:warn).size
    ensure
      ActionController::Base.logger = old_logger
      ActionController::Base.log_warning_on_csrf_failure = true
    end
  end

  def test_should_only_allow_same_origin_js_get_with_xhr_header
    assert_cross_origin_blocked { get :same_origin_js }
    assert_cross_origin_blocked { get :same_origin_js, format: 'js' }
    assert_cross_origin_blocked do
      @request.accept = 'text/javascript'
      get :negotiate_same_origin
    end

    assert_cross_origin_blocked do
      @request.accept = 'application/javascript'
      get :negotiate_same_origin
    end

    assert_cross_origin_not_blocked { get :same_origin_js, xhr: true }
    assert_cross_origin_not_blocked { get :same_origin_js, xhr: true, format: 'js' }
    assert_cross_origin_not_blocked do
      @request.accept = 'text/javascript'
      get :negotiate_same_origin, xhr: true
    end
  end

  def test_should_warn_on_not_same_origin_js
    old_logger = ActionController::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    ActionController::Base.logger = logger

    begin
      assert_cross_origin_blocked { get :same_origin_js }

      assert_equal 1, logger.logged(:warn).size
      assert_match(/<script> tag on another site requested protected JavaScript/, logger.logged(:warn).last)
    ensure
      ActionController::Base.logger = old_logger
    end
  end

  def test_should_not_warn_if_csrf_logging_disabled_and_not_same_origin_js
    old_logger = ActionController::Base.logger
    logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    ActionController::Base.logger = logger
    ActionController::Base.log_warning_on_csrf_failure = false

    begin
      assert_cross_origin_blocked { get :same_origin_js }

      assert_equal 0, logger.logged(:warn).size
    ensure
      ActionController::Base.logger = old_logger
      ActionController::Base.log_warning_on_csrf_failure = true
    end
  end

  # Allow non-GET requests since GET is all a remote <script> tag can muster.
  def test_should_allow_non_get_js_without_xhr_header
    session[:_csrf_token] = @token
    assert_cross_origin_not_blocked { post :same_origin_js, params: { custom_authenticity_token: @token } }
    assert_cross_origin_not_blocked { post :same_origin_js, params: { format: 'js', custom_authenticity_token: @token } }
    assert_cross_origin_not_blocked do
      @request.accept = 'text/javascript'
      post :negotiate_same_origin, params: { custom_authenticity_token: @token }
    end
  end

  def test_should_only_allow_cross_origin_js_get_without_xhr_header_if_protection_disabled
    assert_cross_origin_not_blocked { get :cross_origin_js }
    assert_cross_origin_not_blocked { get :cross_origin_js, format: 'js' }
    assert_cross_origin_not_blocked do
      @request.accept = 'text/javascript'
      get :negotiate_cross_origin
    end

    assert_cross_origin_not_blocked { get :cross_origin_js, xhr: true }
    assert_cross_origin_not_blocked { get :cross_origin_js, xhr: true, format: 'js' }
    assert_cross_origin_not_blocked do
      @request.accept = 'text/javascript'
      get :negotiate_cross_origin, xhr: true
    end
  end

  def test_should_not_trigger_content_type_deprecation
    original = ActionDispatch::Response.return_only_media_type_on_content_type
    ActionDispatch::Response.return_only_media_type_on_content_type = true

    assert_not_deprecated { get :same_origin_js, xhr: true }
  ensure
    ActionDispatch::Response.return_only_media_type_on_content_type = original
  end

  def test_should_not_raise_error_if_token_is_not_a_string
    assert_blocked do
      patch :index, params: { custom_authenticity_token: { foo: 'bar' } }
    end
  end

  def assert_blocked
    session[:something_like_user_id] = 1
    yield
    assert_nil session[:something_like_user_id], 'session values are still present'
    assert_response :success
  end

  def assert_not_blocked(&block)
    assert_nothing_raised(&block)
    assert_response :success
  end

  def assert_cross_origin_blocked
    assert_raises(ActionController::InvalidCrossOriginRequest) do
      yield
    end
  end

  def assert_cross_origin_not_blocked
    assert_not_blocked { yield }
  end

  def forgery_protection_origin_check
    old_setting = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.forgery_protection_origin_check = true
    begin
      yield
    ensure
      ActionController::Base.forgery_protection_origin_check = old_setting
    end
  end
end

# OK let's get our test on

class RequestForgeryProtectionControllerUsingResetSessionTest < ActionController::TestCase
  include RequestForgeryProtectionTests

  test 'should emit a csrf-param meta tag and a csrf-token meta tag' do
    @controller.stub :form_authenticity_token, @token + '<=?' do
      get :meta
      assert_select 'meta[name=?][content=?]', 'csrf-param', 'custom_authenticity_token'
      assert_select 'meta[name=?]', 'csrf-token'
      regexp = "#{@token}&lt;=\?"
      assert_match(/#{regexp}/, @response.body)
    end
  end
end

class RequestForgeryProtectionControllerUsingNullSessionTest < ActionController::TestCase
  class NullSessionDummyKeyGenerator
    def generate_key(secret, length = nil)
      '03312270731a2ed0d11ed091c2338a06'
    end
  end

  def setup
    @request.env[ActionDispatch::Cookies::GENERATOR_KEY] = NullSessionDummyKeyGenerator.new
    @request.env[ActionDispatch::Cookies::COOKIES_ROTATIONS] = ActiveSupport::Messages::RotationConfiguration.new
  end

  test 'should allow to set signed cookies' do
    post :signed
    assert_response :ok
  end

  test 'should allow to set encrypted cookies' do
    post :encrypted
    assert_response :ok
  end

  test 'should allow reset_session' do
    post :try_to_reset_session
    assert_response :ok
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

class PrependProtectForgeryBaseControllerTest < ActionController::TestCase
  PrependTrueController = Class.new(PrependProtectForgeryBaseController) do
    protect_from_forgery prepend: true
  end

  PrependFalseController = Class.new(PrependProtectForgeryBaseController) do
    protect_from_forgery prepend: false
  end

  PrependDefaultController = Class.new(PrependProtectForgeryBaseController) do
    protect_from_forgery
  end

  def test_verify_authenticity_token_is_prepended
    @controller = PrependTrueController.new
    get :index
    expected_callback_order = ['verify_authenticity_token', 'custom_action']
    assert_equal(expected_callback_order, @controller.called_callbacks)
  end

  def test_verify_authenticity_token_is_not_prepended
    @controller = PrependFalseController.new
    get :index
    expected_callback_order = ['custom_action', 'verify_authenticity_token']
    assert_equal(expected_callback_order, @controller.called_callbacks)
  end

  def test_verify_authenticity_token_is_not_prepended_by_default
    @controller = PrependDefaultController.new
    get :index
    expected_callback_order = ['custom_action', 'verify_authenticity_token']
    assert_equal(expected_callback_order, @controller.called_callbacks)
  end
end

class FreeCookieControllerTest < ActionController::TestCase
  def setup
    @controller = FreeCookieController.new
    @token      = 'cf50faa3fe97702ca1ae'
    super
  end

  def test_should_not_render_form_with_token_tag
    SecureRandom.stub :urlsafe_base64, @token do
      get :index
      assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token, false
    end
  end

  def test_should_not_render_button_to_with_token_tag
    SecureRandom.stub :urlsafe_base64, @token do
      get :show_button
      assert_select 'form>div>input[name=?][value=?]', 'authenticity_token', @token, false
    end
  end

  def test_should_allow_all_methods_without_token
    SecureRandom.stub :urlsafe_base64, @token do
      [:post, :patch, :put, :delete].each do |method|
        assert_nothing_raised { send(method, :index) }
      end
    end
  end

  test 'should not emit a csrf-token meta tag' do
    SecureRandom.stub :urlsafe_base64, @token do
      get :meta
      assert_predicate @response.body, :blank?
    end
  end
end

class CustomAuthenticityParamControllerTest < ActionController::TestCase
  def setup
    super
    @old_logger = ActionController::Base.logger
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @token = Base64.urlsafe_encode64(SecureRandom.random_bytes(32))
    @old_request_forgery_protection_token = ActionController::Base.request_forgery_protection_token
    ActionController::Base.request_forgery_protection_token = @token
  end

  def teardown
    ActionController::Base.request_forgery_protection_token = @old_request_forgery_protection_token
    super
  end

  def test_should_not_warn_if_form_authenticity_param_matches_form_authenticity_token
    ActionController::Base.logger = @logger
    begin
      @controller.stub :valid_authenticity_token?, :true do
        post :index, params: { custom_token_name: 'foobar' }
        assert_equal 0, @logger.logged(:warn).size
      end
    ensure
      ActionController::Base.logger = @old_logger
    end
  end

  def test_should_warn_if_form_authenticity_param_does_not_match_form_authenticity_token
    ActionController::Base.logger = @logger

    begin
      post :index, params: { custom_token_name: 'bazqux' }
      assert_equal 1, @logger.logged(:warn).size
    ensure
      ActionController::Base.logger = @old_logger
    end
  end
end

class PerFormTokensControllerTest < ActionController::TestCase
  def setup
    @old_request_forgery_protection_token = ActionController::Base.request_forgery_protection_token
    ActionController::Base.request_forgery_protection_token = :custom_authenticity_token
  end

  def teardown
    ActionController::Base.request_forgery_protection_token = @old_request_forgery_protection_token
  end

  def test_per_form_token_is_same_size_as_global_token
    get :index
    expected = ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH
    actual = @controller.send(:per_form_csrf_token, session, '/path', 'post').size
    assert_equal expected, actual
  end

  def test_accepts_token_for_correct_path_and_method
    get :index

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
    assert_response :success
  end

  def test_accepts_token_with_path_with_query_params
    get :index
    form_token = assert_presence_and_fetch_form_csrf_token
    assert_matches_session_token_on_server form_token

    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    @request.env['QUERY_STRING'] = 'key=value'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
  end

  def test_rejects_garbage_path
    get :index

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token

    # Set invalid URI in PATH_INFO
    @request.env['PATH_INFO'] = '/foo/bar<'
    assert_raise ActionController::InvalidAuthenticityToken do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
  end

  def test_rejects_token_for_incorrect_path
    get :index

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_two'
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post :post_two, params: { custom_authenticity_token: form_token }
    end
  end

  def test_rejects_token_for_incorrect_method
    get :index

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_raises(ActionController::InvalidAuthenticityToken) do
      patch :post_one, params: { custom_authenticity_token: form_token }
    end
  end

  def test_rejects_token_for_incorrect_method_button_to
    get :button_to, params: { form_method: 'delete' }

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token, 'delete'

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_raises(ActionController::InvalidAuthenticityToken) do
      patch :post_one, params: { custom_authenticity_token: form_token }
    end
  end

  test 'Accepts proper token for implicit post method on button_to tag' do
    get :button_to

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token, 'post'

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
  end

  %w{delete post patch}.each do |verb|
    test "Accepts proper token for #{verb} method on button_to tag" do
      get :button_to, params: { form_method: verb }

      form_token = assert_presence_and_fetch_form_csrf_token

      assert_matches_session_token_on_server form_token, verb

      # This is required because PATH_INFO isn't reset between requests.
      @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
      assert_nothing_raised do
        send verb, :post_one, params: { custom_authenticity_token: form_token }
      end
    end
  end

  def test_accepts_global_csrf_token
    get :index

    token = @controller.send(:form_authenticity_token)

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: token }
    end
    assert_response :success
  end

  def test_does_not_return_old_csrf_token
    get :index

    token = @controller.send(:form_authenticity_token)

    unmasked_token = @controller.send(:unmask_token, Base64.urlsafe_decode64(token))

    assert_not_equal @controller.send(:real_csrf_token, session), unmasked_token
  end

  def test_returns_hmacd_token
    get :index

    token = @controller.send(:form_authenticity_token)

    unmasked_token = @controller.send(:unmask_token, Base64.urlsafe_decode64(token))

    assert_equal @controller.send(:global_csrf_token, session), unmasked_token
  end

  def test_accepts_old_csrf_token
    get :index

    non_hmac_token = @controller.send(:mask_token, @controller.send(:real_csrf_token, session))

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: non_hmac_token }
    end
    assert_response :success
  end

  def test_chomps_slashes
    get :index, params: { form_path: '/per_form_tokens/post_one?foo=bar' }

    form_token = assert_presence_and_fetch_form_csrf_token

    assert_matches_session_token_on_server form_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one/'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token, baz: 'foo' }
    end
    assert_response :success
  end

  def test_ignores_trailing_slash_during_generation
    get :index, params: { form_path: '/per_form_tokens/post_one/' }

    form_token = assert_presence_and_fetch_form_csrf_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
    assert_response :success
  end

  def test_ignores_origin_during_generation
    get :index, params: { form_path: 'https://example.com/per_form_tokens/post_one/' }

    form_token = assert_presence_and_fetch_form_csrf_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
    assert_response :success
  end

  def test_ignores_trailing_slash_during_validation
    get :index

    form_token = assert_presence_and_fetch_form_csrf_token

    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one/'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
    assert_response :success
  end

  def test_method_is_case_insensitive
    get :index, params: { form_method: 'POST' }

    form_token = assert_presence_and_fetch_form_csrf_token
    # This is required because PATH_INFO isn't reset between requests.
    @request.env['PATH_INFO'] = '/per_form_tokens/post_one/'
    assert_nothing_raised do
      post :post_one, params: { custom_authenticity_token: form_token }
    end
    assert_response :success
  end

  private
    def assert_presence_and_fetch_form_csrf_token
      assert_select 'input[name="custom_authenticity_token"]' do |input|
        form_csrf_token = input.first['value']
        assert_not_nil form_csrf_token
        return form_csrf_token
      end
    end

    def assert_matches_session_token_on_server(form_token, method = 'post')
      actual = @controller.send(:unmask_token, Base64.urlsafe_decode64(form_token))
      expected = @controller.send(:per_form_csrf_token, session, '/per_form_tokens/post_one', method)
      assert_equal expected, actual
    end
end

class SkipProtectionControllerTest < ActionController::TestCase
  def test_should_not_allow_post_without_token_when_not_skipping
    @controller.skip_requested = false
    assert_blocked { post :index }
  end

  def test_should_allow_post_without_token_when_skipping
    @controller.skip_requested = true
    assert_not_blocked { post :index }
  end

  def assert_blocked
    assert_raises(ActionController::InvalidAuthenticityToken) do
      yield
    end
  end

  def assert_not_blocked(&block)
    assert_nothing_raised(&block)
    assert_response :success
  end
end
