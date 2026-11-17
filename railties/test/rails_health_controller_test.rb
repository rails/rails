# frozen_string_literal: true

require "abstract_unit"

class HealthControllerTest < ActionController::TestCase
  tests Rails::HealthController

  def setup
    Rails.application.routes.draw do
      get "/up" => "rails/health#show", as: :rails_health_check
    end
    @routes = Rails.application.routes
  end

  test "health controller renders green success page in HTML" do
    get :show, format: :html
    assert_response :success
    assert_match(/background-color: green/, @response.body)
  end

  test "health controller renders red internal server error page in HTML" do
    @controller.instance_eval do
      def render_up
        raise Exception, "some exception"
      end
    end
    get :show, format: :html
    assert_response :internal_server_error
    assert_match(/background-color: red/, @response.body)
  end

  test "health controller returns JSON success response" do
    get :show, format: :json
    assert_response :success
    assert_includes @response.content_type, "application/json"

    json_response = JSON.parse(@response.body)
    assert_equal "up", json_response["status"]
    assert_includes json_response, "timestamp"
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, json_response["timestamp"])
  end

  test "health controller returns JSON error response" do
    @controller.instance_eval do
      def render_up
        raise Exception, "some exception"
      end
    end
    get :show, format: :json
    assert_response :internal_server_error
    assert_includes @response.content_type, "application/json"

    json_response = JSON.parse(@response.body)
    assert_equal "down", json_response["status"]
    assert_includes json_response, "timestamp"
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, json_response["timestamp"])
  end
end
