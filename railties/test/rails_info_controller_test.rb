require 'abstract_unit'
require 'action_controller'

module ActionController
  class Base
    include ActionController::Testing
  end
end

class InfoControllerTest < ActionController::TestCase
  tests Rails::InfoController

  def setup
    Rails.application.routes.draw do
      match '/rails/info/properties' => "rails/info#properties"
    end
    @request.stubs(:local? => true)
    @controller.stubs(:consider_all_requests_local? => false)
    @routes = Rails.application.routes

    Rails::InfoController.send(:include, @routes.url_helpers)
  end

  test "info controller does not allow remote requests" do
    @request.stubs(:local? => false)
    get :properties
    assert_response :forbidden
  end

  test "info controller renders an error message when request was forbidden" do
    @request.stubs(:local? => false)
    get :properties
    assert_select 'p'
  end

  test "info controller allows requests when all requests are considered local" do
    @request.stubs(:local? => false)
    @controller.stubs(:consider_all_requests_local? => true)
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
end
