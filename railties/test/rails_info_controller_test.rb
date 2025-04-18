# frozen_string_literal: true

require "abstract_unit"

class InfoControllerTest < ActionController::TestCase
  include ActiveSupport::Testing::Isolation
  tests Rails::InfoController

  def setup
    ActionController::Base.include ActionController::Testing

    Rails.application.routes.draw do
      namespace :test do
        get :nested_route, to: "test#show"
      end
      get "/rails/info/properties" => "rails/info#properties"
      get "/rails/info/routes" => "rails/info#routes"
      get "/rails/info/notes" => "rails/info#notes"
      post "/rails/:test/properties" => "rails/info#properties"
      put "/rails/:test/named_properties" => "rails/info#properties", as: "named_rails_info_properties"
    end
    @routes = Rails.application.routes

    Rails::InfoController.include(@routes.url_helpers)

    @request.env["REMOTE_ADDR"] = "127.0.0.1"
  end

  def exact_results
    JSON(response.body)["exact"]
  end

  def fuzzy_results
    JSON(response.body)["fuzzy"]
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
    @request.env["REMOTE_ADDR"] = "example.org"
    Rails.application.config.consider_all_requests_local = true
    get :properties
    assert_response :success
  ensure
    Rails.application.config.consider_all_requests_local = false
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

  test "info controller routes shows source location" do
    Rails.env = "development"
    Rails.configuration.eager_load = false
    Rails.application.initialize!
    Rails.application.routes.draw do
      namespace :test do
        get :nested_route, to: "test#show"
      end
      get "/rails/info/routes" => "rails/info#routes"
    end

    get :routes

    assert_select("table tr") do
      assert_select("td", text: "test_nested_route_path")
      assert_select("td", text: "test/test#show")
      assert_select("td", text: "#{__FILE__}:79")
    end
  end

  test "info controller search returns exact matches for route names" do
    get :routes, params: { query: "rails_info_" }
    assert exact_results.size == 0, "should not match incomplete route names"

    get :routes, params: { query: "" }
    assert exact_results.size == 0, "should not match unnamed routes"

    get :routes, params: { query: "rails_info_properties" }
    assert exact_results.size == 1, "should match complete route names"
    assert exact_results.include? "/rails/info/properties(.:format)"

    get :routes, params: { query: "rails_info_properties_path" }
    assert exact_results.size == 1, "should match complete route paths"
    assert exact_results.include? "/rails/info/properties(.:format)"

    get :routes, params: { query: "rails_info_properties_url" }
    assert exact_results.size == 1, "should match complete route urls"
    assert exact_results.include? "/rails/info/properties(.:format)"
  end

  test "info controller search returns exact matches for route paths" do
    get :routes, params: { query: "rails/info/route" }
    assert exact_results.size == 0, "should not match incomplete route paths"

    get :routes, params: { query: "/rails/info/routes" }
    assert exact_results.size == 1, "should match complete route paths prefixed with /"
    assert exact_results.include? "/rails/info/routes(.:format)"

    get :routes, params: { query: "rails/info/routes" }
    assert exact_results.size == 1, "should match complete route paths NOT prefixed with /"
    assert exact_results.include? "/rails/info/routes(.:format)"

    get :routes, params: { query: "rails/info/routes.html" }
    assert exact_results.size == 1, "should match complete route paths with optional parts"
    assert exact_results.include? "/rails/info/routes(.:format)"

    get :routes, params: { query: "test/nested_route" }
    assert exact_results.size == 1, "should match complete route paths that are nested in a namespace"
    assert exact_results.include? "/test/nested_route(.:format)"
  end

  test "info controller search returns case-sensitive exact matches for HTTP Verb methods" do
    get :routes, params: { query: "GE" }
    assert exact_results.size == 0, "should not match incomplete HTTP Verb methods"

    get :routes, params: { query: "get" }
    assert exact_results.size == 0, "should not case-insensitive match HTTP Verb methods"

    get :routes, params: { query: "GET" }
    assert exact_results.size == 4, "should match complete HTTP Verb methods"
    assert exact_results.include? "/test/nested_route(.:format)"
    assert exact_results.include? "/rails/info/properties(.:format)"
    assert exact_results.include? "/rails/info/routes(.:format)"
    assert exact_results.include? "/rails/info/notes(.:format)"
  end

  test "info controller search returns exact matches for route Controller#Action(s)" do
    get :routes, params: { query: "rails/info#propertie" }
    assert exact_results.size == 0, "should not match incomplete route Controller#Action(s)"

    get :routes, params: { query: "rails/info#properties" }
    assert exact_results.size == 3, "should match complete route Controller#Action(s)"
    assert exact_results.include? "/rails/info/properties(.:format)"
    assert exact_results.include? "/rails/:test/properties(.:format)"
    assert exact_results.include? "/rails/:test/named_properties(.:format)"
  end

  test "info controller returns fuzzy matches for route names" do
    get :routes, params: { query: "" }
    assert exact_results.size == 0, "should not match unnamed routes"

    get :routes, params: { query: "rails_info" }
    assert fuzzy_results.size == 4, "should match incomplete route names"
    assert fuzzy_results.include? "/rails/info/properties(.:format)"
    assert fuzzy_results.include? "/rails/info/routes(.:format)"
    assert fuzzy_results.include? "/rails/info/notes(.:format)"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"

    get :routes, params: { query: "/rails/info/routes" }
    assert fuzzy_results.size == 1, "should match complete route names"
    assert fuzzy_results.include? "/rails/info/routes(.:format)"

    get :routes, params: { query: "named_rails_info_properties_path" }
    assert fuzzy_results.size == 1, "should match complete route paths"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"

    get :routes, params: { query: "named_rails_info_properties_url" }
    assert fuzzy_results.size == 1, "should match complete route urls"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"
  end

  test "info controller returns fuzzy matches for route paths" do
    get :routes, params: { query: "rails/:test" }
    assert fuzzy_results.size == 2, "should match incomplete routes"
    assert fuzzy_results.include? "/rails/:test/properties(.:format)"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"

    get :routes, params: { query: "/rails/info/routes" }
    assert fuzzy_results.size == 1, "should match complete routes"
    assert fuzzy_results.include? "/rails/info/routes(.:format)"

    get :routes, params: { query: "rails/info/routes.html" }
    assert fuzzy_results.size == 0, "should match optional parts of route literally"
  end

  # Intentionally ignoring fuzzy match of HTTP Verb methods. There's not much value to 'GE' returning 'GET' results.

  test "info controller search returns fuzzy matches for route Controller#Action(s)" do
    get :routes, params: { query: "rails/info#propertie" }
    assert fuzzy_results.size == 3, "should match incomplete routes"
    assert fuzzy_results.include? "/rails/info/properties(.:format)"
    assert fuzzy_results.include? "/rails/:test/properties(.:format)"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"

    get :routes, params: { query: "rails/info#properties" }
    assert fuzzy_results.size == 3, "should match complete route Controller#Action(s)"
    assert fuzzy_results.include? "/rails/info/properties(.:format)"
    assert fuzzy_results.include? "/rails/:test/properties(.:format)"
    assert fuzzy_results.include? "/rails/:test/named_properties(.:format)"
  end

  test "internal routes do not have a default params[:internal] value" do
    get :properties
    assert_response :success
    assert_nil @controller.params[:internal]
  end
end
