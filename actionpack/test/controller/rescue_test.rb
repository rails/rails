require "abstract_unit"

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
  rescue_from "RescueController::NotAuthorizedToRescueAsString", :with => :deny_access

  rescue_from RecordInvalid, :with => :show_errors
  rescue_from "RescueController::RecordInvalidToRescueAsString", :with => :show_errors

  rescue_from NotAllowed, :with => proc { head :forbidden }
  rescue_from "RescueController::NotAllowedToRescueAsString", :with => proc { head :forbidden }

  rescue_from InvalidRequest, with: proc { |exception| render plain: exception.message }
  rescue_from "InvalidRequestToRescueAsString", with: proc { |exception| render plain: exception.message }

  rescue_from BadGateway do
    head 502
  end
  rescue_from "BadGatewayToRescueAsString" do
    head 502
  end

  rescue_from ResourceUnavailable do |exception|
    render plain: exception.message
  end
  rescue_from "ResourceUnavailableToRescueAsString" do |exception|
    render plain: exception.message
  end

  rescue_from ActionView::TemplateError do
    render plain: "action_view templater error"
  end

  rescue_from IOError do
    render plain: "io error"
  end

  before_action(only: :before_action_raises) { raise "umm nice" }

  def before_action_raises
  end

  def raises
    render plain: "already rendered"
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

  def exception_with_more_specific_handler_for_wrapper
    raise RecordInvalid
  rescue
    raise NotAuthorized
  end

  def exception_with_more_specific_handler_for_cause
    raise NotAuthorized
  rescue
    raise RecordInvalid
  end

  def exception_with_no_handler_for_wrapper
    raise RecordInvalid
  rescue
    raise RangeError
  end

  protected
    def deny_access
      head :forbidden
    end

    def show_errors(exception)
      head :unprocessable_entity
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

  rescue_from FirstExceptionInChildController, "SecondExceptionInChildController", :with => lambda { head :gone }

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

class RescueControllerTest < ActionController::TestCase
  def test_rescue_handler
    get :not_authorized
    assert_response :forbidden
  end
  def test_rescue_handler_string
    get :not_authorized_raise_as_string
    assert_response :forbidden
  end

  def test_rescue_handler_with_argument
    assert_called_with @controller, :show_errors, [Exception] do
      get :record_invalid
    end
  end
  def test_rescue_handler_with_argument_as_string
    assert_called_with @controller, :show_errors, [Exception] do
      get :record_invalid_raise_as_string
    end
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

  test "rescue when wrapper has more specific handler than cause" do
    get :exception_with_more_specific_handler_for_wrapper
    assert_response :forbidden
  end

  test "rescue when cause has more specific handler than wrapper" do
    get :exception_with_more_specific_handler_for_cause
    assert_response :unprocessable_entity
  end

  test "rescue when cause has handler, but wrapper doesnt" do
    get :exception_with_no_handler_for_wrapper
    assert_response :unprocessable_entity
  end
end

class RescueTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    class RecordInvalid < StandardError
      def message
        "invalid"
      end
    end
    rescue_from RecordInvalid, :with => :show_errors

    def foo
      render plain: "foo"
    end

    def invalid
      raise RecordInvalid
    end

    def b00m
      raise "b00m"
    end

    protected
      def show_errors(exception)
        render plain: exception.message
      end
  end

  test "normal request" do
    with_test_routing do
      get "/foo"
      assert_equal "foo", response.body
    end
  end

  test "rescue exceptions inside controller" do
    with_test_routing do
      get "/invalid"
      assert_equal "invalid", response.body
    end
  end

  private

    def with_test_routing
      with_routing do |set|
        set.draw do
          get "foo", :to => ::RescueTest::TestController.action(:foo)
          get "invalid", :to => ::RescueTest::TestController.action(:invalid)
          get "b00m", :to => ::RescueTest::TestController.action(:b00m)
        end
        yield
      end
    end
end
