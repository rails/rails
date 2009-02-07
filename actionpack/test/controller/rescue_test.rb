require 'abstract_unit'

class RescueController < ActionController::Base
  class NotAuthorized < StandardError
  end
  class NotAuthorizedToRescueAsString < StandardError
  end

  class RecordInvalid < StandardError
  end
  class RecordInvalidToRescueAsString < StandardError
  end

  class NotAllowed < StandardError
  end
  class NotAllowedToRescueAsString < StandardError
  end

  class InvalidRequest < StandardError
  end
  class InvalidRequestToRescueAsString < StandardError
  end

  class BadGateway < StandardError
  end
  class BadGatewayToRescueAsString < StandardError
  end

  class ResourceUnavailable < StandardError
  end
  class ResourceUnavailableToRescueAsString < StandardError
  end

  # We use a fully-qualified name in some strings, and a relative constant
  # name in some other to test correct handling of both cases.

  rescue_from NotAuthorized, :with => :deny_access
  rescue_from 'RescueController::NotAuthorizedToRescueAsString', :with => :deny_access

  rescue_from RecordInvalid, :with => :show_errors
  rescue_from 'RescueController::RecordInvalidToRescueAsString', :with => :show_errors

  rescue_from NotAllowed, :with => proc { head :forbidden }
  rescue_from 'RescueController::NotAllowedToRescueAsString', :with => proc { head :forbidden }

  rescue_from InvalidRequest, :with => proc { |exception| render :text => exception.message }
  rescue_from 'InvalidRequestToRescueAsString', :with => proc { |exception| render :text => exception.message }

  rescue_from BadGateway do
    head :status => 502
  end
  rescue_from 'BadGatewayToRescueAsString' do
    head :status => 502
  end

  rescue_from ResourceUnavailable do |exception|
    render :text => exception.message
  end
  rescue_from 'ResourceUnavailableToRescueAsString' do |exception|
    render :text => exception.message
  end

  # This is a Dispatcher exception and should be in ApplicationController.
  rescue_from ActionController::RoutingError do
    render :text => 'no way'
  end

  before_filter(:only => :before_filter_raises) { raise 'umm nice' }

  def before_filter_raises
  end

  def raises
    render :text => 'already rendered'
    raise "don't panic!"
  end

  def method_not_allowed
    raise ActionController::MethodNotAllowed.new(:get, :head, :put)
  end

  def not_implemented
    raise ActionController::NotImplemented.new(:get, :put)
  end

  def not_authorized
    raise NotAuthorized
  end
  def not_authorized_raise_as_string
    raise NotAuthorizedToRescueAsString
  end

  def not_allowed
    raise NotAllowed
  end
  def not_allowed_raise_as_string
    raise NotAllowedToRescueAsString
  end

  def invalid_request
    raise InvalidRequest
  end
  def invalid_request_raise_as_string
    raise InvalidRequestToRescueAsString
  end

  def record_invalid
    raise RecordInvalid
  end
  def record_invalid_raise_as_string
    raise RecordInvalidToRescueAsString
  end

  def bad_gateway
    raise BadGateway
  end
  def bad_gateway_raise_as_string
    raise BadGatewayToRescueAsString
  end

  def resource_unavailable
    raise ResourceUnavailable
  end
  def resource_unavailable_raise_as_string
    raise ResourceUnavailableToRescueAsString
  end

  def missing_template
  end

  protected
    def deny_access
      head :forbidden
    end

    def show_errors(exception)
      head :unprocessable_entity
    end
end

class RescueControllerTest < ActionController::TestCase
  FIXTURE_PUBLIC = "#{File.dirname(__FILE__)}/../fixtures".freeze

  setup :set_all_requests_local
  setup :populate_exception_object

  def set_all_requests_local
    RescueController.consider_all_requests_local = true
    @request.remote_addr = '1.2.3.4'
    @request.host = 'example.com'
  end

  def populate_exception_object
    begin
      raise 'foo'
    rescue => @exception
    end
  end

  def test_rescue_exceptions_raised_by_filters
    with_rails_root FIXTURE_PUBLIC do
      with_all_requests_local false do
        get :before_filter_raises
      end
    end

    assert_response :internal_server_error
  end

  def test_rescue_action_locally_if_all_requests_local
    @controller.expects(:local_request?).never
    @controller.expects(:rescue_action_locally).with(@exception)
    @controller.expects(:rescue_action_in_public).never

    with_all_requests_local do
      @controller.send :rescue_action, @exception
    end
  end

  def test_rescue_action_locally_if_remote_addr_is_localhost
    @controller.expects(:local_request?).returns(true)
    @controller.expects(:rescue_action_locally).with(@exception)
    @controller.expects(:rescue_action_in_public).never

    with_all_requests_local false do
      @controller.send :rescue_action, @exception
    end
  end

  def test_rescue_action_in_public_otherwise
    @controller.expects(:local_request?).returns(false)
    @controller.expects(:rescue_action_locally).never
    @controller.expects(:rescue_action_in_public).with(@exception)

    with_all_requests_local false do
      @controller.send :rescue_action, @exception
    end
  end

  def test_rescue_action_in_public_with_localized_error_file
    # Change locale
    old_locale = I18n.locale
    I18n.locale = :da

    with_rails_root FIXTURE_PUBLIC do
      with_all_requests_local false do
        get :raises
      end
    end

    assert_response :internal_server_error
    body = File.read("#{FIXTURE_PUBLIC}/public/500.da.html")
    assert_equal body, @response.body
  ensure
    I18n.locale = old_locale
  end

  def test_rescue_action_in_public_with_error_file
    with_rails_root FIXTURE_PUBLIC do
      with_all_requests_local false do
        get :raises
      end
    end

    assert_response :internal_server_error
    body = File.read("#{FIXTURE_PUBLIC}/public/500.html")
    assert_equal body, @response.body
  end

  def test_rescue_action_in_public_without_error_file
    with_rails_root '/tmp' do
      with_all_requests_local false do
        get :raises
      end
    end

    assert_response :internal_server_error
    assert_equal ' ', @response.body
  end

  def test_rescue_unknown_action_in_public_with_error_file
    with_rails_root FIXTURE_PUBLIC do
      with_all_requests_local false do
        get :foobar_doesnt_exist
      end
    end

    assert_response :not_found
    body = File.read("#{FIXTURE_PUBLIC}/public/404.html")
    assert_equal body, @response.body
  end

  def test_rescue_unknown_action_in_public_without_error_file
    with_rails_root '/tmp' do
      with_all_requests_local false do
        get :foobar_doesnt_exist
      end
    end

    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_rescue_missing_template_in_public
    with_rails_root FIXTURE_PUBLIC do
      with_all_requests_local true do
        get :missing_template
      end
    end

    assert_response :internal_server_error
    assert @response.body.include?('missing_template'), "Response should include the template name."
  end

  def test_rescue_action_locally
    get :raises
    assert_response :internal_server_error
    assert_template 'diagnostics.erb'
    assert @response.body.include?('RescueController#raises'), "Response should include controller and action."
    assert @response.body.include?("don't panic"), "Response should include exception message."
  end

  def test_local_request_when_remote_addr_is_localhost
    @controller.expects(:request).returns(@request).at_least_once
    with_remote_addr '127.0.0.1' do
      assert @controller.send(:local_request?)
    end
  end

  def test_local_request_when_remote_addr_isnt_locahost
    @controller.expects(:request).returns(@request)
    with_remote_addr '1.2.3.4' do
      assert !@controller.send(:local_request?)
    end
  end

  def test_rescue_responses
    responses = ActionController::Base.rescue_responses

    assert_equal ActionController::Rescue::DEFAULT_RESCUE_RESPONSE, responses.default
    assert_equal ActionController::Rescue::DEFAULT_RESCUE_RESPONSE, responses[Exception.new]

    assert_equal :not_found, responses[ActionController::RoutingError.name]
    assert_equal :not_found, responses[ActionController::UnknownAction.name]
    assert_equal :not_found, responses['ActiveRecord::RecordNotFound']
    assert_equal :conflict, responses['ActiveRecord::StaleObjectError']
    assert_equal :unprocessable_entity, responses['ActiveRecord::RecordInvalid']
    assert_equal :unprocessable_entity, responses['ActiveRecord::RecordNotSaved']
    assert_equal :method_not_allowed, responses['ActionController::MethodNotAllowed']
    assert_equal :not_implemented, responses['ActionController::NotImplemented']
  end

  def test_rescue_templates
    templates = ActionController::Base.rescue_templates

    assert_equal ActionController::Rescue::DEFAULT_RESCUE_TEMPLATE, templates.default
    assert_equal ActionController::Rescue::DEFAULT_RESCUE_TEMPLATE, templates[Exception.new]

    assert_equal 'missing_template',  templates[ActionView::MissingTemplate.name]
    assert_equal 'routing_error',     templates[ActionController::RoutingError.name]
    assert_equal 'unknown_action',    templates[ActionController::UnknownAction.name]
    assert_equal 'template_error',    templates[ActionView::TemplateError.name]
  end

  def test_not_implemented
    with_all_requests_local false do
      with_rails_public_path(".") do
        head :not_implemented
      end
    end
    assert_response :not_implemented
    assert_equal "GET, PUT", @response.headers['Allow']
  end

  def test_method_not_allowed
    with_all_requests_local false do
      with_rails_public_path(".") do
        get :method_not_allowed
      end
    end
    assert_response :method_not_allowed
    assert_equal "GET, HEAD, PUT", @response.headers['Allow']
  end

  def test_rescue_handler
    get :not_authorized
    assert_response :forbidden
  end
  def test_rescue_handler_string
    get :not_authorized_raise_as_string
    assert_response :forbidden
  end

  def test_rescue_handler_with_argument
    @controller.expects(:show_errors).once.with { |e| e.is_a?(Exception) }
    get :record_invalid
  end
  def test_rescue_handler_with_argument_as_string
    @controller.expects(:show_errors).once.with { |e| e.is_a?(Exception) }
    get :record_invalid_raise_as_string
  end

  def test_proc_rescue_handler
    get :not_allowed
    assert_response :forbidden
  end
  def test_proc_rescue_handler_as_string
    get :not_allowed_raise_as_string
    assert_response :forbidden
  end

  def test_proc_rescue_handle_with_argument
    get :invalid_request
    assert_equal "RescueController::InvalidRequest", @response.body
  end
  def test_proc_rescue_handle_with_argument_as_string
    get :invalid_request_raise_as_string
    assert_equal "RescueController::InvalidRequestToRescueAsString", @response.body
  end

  def test_block_rescue_handler
    get :bad_gateway
    assert_response 502
  end
  def test_block_rescue_handler_as_string
    get :bad_gateway_raise_as_string
    assert_response 502
  end

  def test_block_rescue_handler_with_argument
    get :resource_unavailable
    assert_equal "RescueController::ResourceUnavailable", @response.body
  end

  def test_block_rescue_handler_with_argument_as_string
    get :resource_unavailable_raise_as_string
    assert_equal "RescueController::ResourceUnavailableToRescueAsString", @response.body
  end

  def test_rescue_dispatcher_exceptions
    env = @request.env
    env["action_controller.rescue.request"] = @request
    env["action_controller.rescue.response"] = @response

    RescueController.call_with_exception(env, ActionController::RoutingError.new("Route not found"))
    assert_equal "no way", @response.body
  end

  def test_rescue_dispatcher_exceptions_without_request_set
    @request.env['REQUEST_URI'] = '/no_way'
    response = RescueController.call_with_exception(@request.env, ActionController::RoutingError.new("Route not found"))
    assert_kind_of ActionController::Response, response
    assert_equal "no way", response.body
  end

  protected
    def with_all_requests_local(local = true)
      old_local, ActionController::Base.consider_all_requests_local =
        ActionController::Base.consider_all_requests_local, local
      yield
    ensure
      ActionController::Base.consider_all_requests_local = old_local
    end

    def with_remote_addr(addr)
      old_remote_addr, @request.remote_addr = @request.remote_addr, addr
      yield
    ensure
      @request.remote_addr = old_remote_addr
    end

    def with_rails_public_path(rails_root)
      old_rails = Object.const_get(:Rails) rescue nil
      mod = Object.const_set(:Rails, Module.new)
      (class << mod; self; end).instance_eval do
        define_method(:public_path) { "#{rails_root}/public" }
      end
      yield
    ensure
      Object.module_eval { remove_const(:Rails) } if defined?(Rails)
      Object.const_set(:Rails, old_rails) if old_rails
    end

    def with_rails_root(path = nil,&block)
      old_rails_root = RAILS_ROOT if defined?(RAILS_ROOT)
      if path
        silence_warnings { Object.const_set(:RAILS_ROOT, path) }
      else
        Object.remove_const(:RAILS_ROOT) rescue nil
      end

      with_rails_public_path(path, &block)

    ensure
      if old_rails_root
        silence_warnings { Object.const_set(:RAILS_ROOT, old_rails_root) }
      else
        Object.remove_const(:RAILS_ROOT) rescue nil
      end
    end
end

class ExceptionInheritanceRescueController < ActionController::Base

  class ParentException < StandardError
  end

  class ChildException < ParentException
  end

  class GrandchildException < ChildException
  end

  rescue_from ChildException,      :with => lambda { head :ok }
  rescue_from ParentException,     :with => lambda { head :created }
  rescue_from GrandchildException, :with => lambda { head :no_content }

  def raise_parent_exception
    raise ParentException
  end

  def raise_child_exception
    raise ChildException
  end

  def raise_grandchild_exception
    raise GrandchildException
  end
end

class ExceptionInheritanceRescueControllerTest < ActionController::TestCase
  def test_bottom_first
    get :raise_grandchild_exception
    assert_response :no_content
  end

  def test_inheritance_works
    get :raise_child_exception
    assert_response :created
  end
end

class ControllerInheritanceRescueController < ExceptionInheritanceRescueController
  class FirstExceptionInChildController < StandardError
  end

  class SecondExceptionInChildController < StandardError
  end

  rescue_from FirstExceptionInChildController, 'SecondExceptionInChildController', :with => lambda { head :gone }

  def raise_first_exception_in_child_controller
    raise FirstExceptionInChildController
  end

  def raise_second_exception_in_child_controller
    raise SecondExceptionInChildController
  end
end

class ControllerInheritanceRescueControllerTest < ActionController::TestCase
  def test_first_exception_in_child_controller
    get :raise_first_exception_in_child_controller
    assert_response :gone
  end

  def test_second_exception_in_child_controller
    get :raise_second_exception_in_child_controller
    assert_response :gone
  end

  def test_exception_in_parent_controller
    get :raise_parent_exception
    assert_response :created
  end
end
