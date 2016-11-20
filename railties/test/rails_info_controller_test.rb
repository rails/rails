require "abstract_unit"

module ActionController
  class Base
    include ActionController::Testing
  end
end

class InfoControllerTest < ActionController::TestCase
  tests Rails::InfoController

  def setup
    Rails.application.routes.draw do
      get "/rails/info/properties" => "rails/info#properties"
      get "/rails/info/routes"     => "rails/info#routes"
    end
    @routes = Rails.application.routes

    Rails::InfoController.include(@routes.url_helpers)

    @request.env["REMOTE_ADDR"] = "127.0.0.1"
  end

  test "info controller does not allow remote requests" do
    @request.env["REMOTE_ADDR"] = "example.org"
    get :properties
    assert_response :forbidden
  end

  test "info controller renders an error message when request was forbidden" do
    @request.env["REMOTE_ADDR"] = "example.org"
    get :properties
    assert_select "p"
  end

  test "info controller allows requests when all requests are considered local" do
    get :properties
    assert_response :success
  end

  test "info controller allows local requests" do
    get :properties
    assert_response :success
  end

  test "info controller renders a table with properties" do
    get :properties
    assert_select "table"
  end

  test "info controller renders with routes" do
    get :routes
    assert_response :success
  end

  test "info controller returns exact matches" do
    exact_count = -> { JSON(response.body)["exact"].size }

    get :routes, params: { path: "rails/info/route" }
    assert exact_count.call == 0, "should not match incomplete routes"

    get :routes, params: { path: "rails/info/routes" }
    assert exact_count.call == 1, "should match complete routes"

    get :routes, params: { path: "rails/info/routes.html" }
    assert exact_count.call == 1, "should match complete routes with optional parts"
  end

  test "info controller returns fuzzy matches" do
    fuzzy_count = -> { JSON(response.body)["fuzzy"].size }

    get :routes, params: { path: "rails/info" }
    assert fuzzy_count.call == 2, "should match incomplete routes"

    get :routes, params: { path: "rails/info/routes" }
    assert fuzzy_count.call == 1, "should match complete routes"

    get :routes, params: { path: "rails/info/routes.html" }
    assert fuzzy_count.call == 0, "should match optional parts of route literally"
  end

  test "internal routes do not have a default params[:internal] value" do
    get :properties
    assert_response :success
    assert_nil @controller.params[:internal]
  end
end
