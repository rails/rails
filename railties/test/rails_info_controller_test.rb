require 'abstract_unit'

module ActionController
  class Base
    include ActionController::Testing
  end
end

class InfoControllerTest < ActionController::TestCase
  tests Rails::InfoController

  def setup
    Rails.application.routes.draw do
      get '/rails/info/properties' => "rails/info#properties"
      get '/rails/info/routes'     => "rails/info#routes"
    end
    @routes = Rails.application.routes

    Rails::InfoController.send(:include, @routes.url_helpers)

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
    assert_select 'p'
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
    assert_select 'table'
  end

  test "info controller renders with routes" do
    get :routes
    assert_response :success
  end

end
