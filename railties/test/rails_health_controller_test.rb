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

  test "health controller renders green success page" do
    get :show
    assert_response :success
    assert_match(/background-color: green/, @response.body)
  end

  test "health controller renders red internal server error page" do
    @controller.instance_eval do
      def render_up
        raise Exception, "some exception"
      end
    end
    get :show
    assert_response :internal_server_error
    assert_match(/background-color: red/, @response.body)
  end
end
