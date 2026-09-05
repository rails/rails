# frozen_string_literal: true

require "abstract_unit"

class PwaControllerTest < ActionController::TestCase
  tests Rails::PwaController

  def setup
    Rails.application.routes.draw do
      get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
      get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
    end
    @routes = Rails.application.routes
    @controller.prepend_view_path File.expand_path("fixtures/views", __dir__)
  end

  test "manifest renders JSON when the request does not specify a format" do
    get :manifest
    assert_response :success
    assert_equal "application/json", @response.media_type
    assert_equal "TestApp", JSON.parse(@response.body)["name"]
  end

  test "service worker renders JavaScript when the request does not specify a format" do
    get :service_worker
    assert_response :success
    assert_equal "text/javascript", @response.media_type
    assert_includes @response.body, "addEventListener"
  end
end
