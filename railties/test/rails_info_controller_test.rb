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
    @controller.stubs(:local_request? => true)
    @routes = Rails.application.routes

    Rails::InfoController.send(:include, @routes.url_helpers)
  end

  test "info controller does not allow remote requests" do
    @controller.stubs(local_request?: false)
    get :properties
    assert_response :forbidden
  end

  test "info controller renders an error message when request was forbidden" do
    @controller.stubs(local_request?: false)
    get :properties
    assert_select 'p'
  end

  test "info controller allows requests when all requests are considered local" do
    @controller.stubs(local_request?: true)
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
