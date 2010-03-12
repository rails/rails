require 'abstract_unit'
require 'action_controller'

require 'rails/info'
require 'rails/info_controller'

module ActionController
  class Base
    include ActionController::Testing
  end
end

class InfoControllerTest < ActionController::TestCase
  tests Rails::InfoController

  def setup
    Rails.application.routes.draw do |map|
      match '/rails/info/properties' => "rails/info#properties"
    end
    @controller.stubs(:consider_all_requests_local? => false, :local_request? => true)
    @router = Rails.application.routes

    Rails::InfoController.send(:include, @router.url_helpers)
  end

  test "info controller does not allow remote requests" do
    @controller.stubs(:consider_all_requests_local? => false, :local_request? => false)
    get :properties
    assert_response :forbidden
  end

  test "info controller renders an error message when request was forbidden" do
    @controller.stubs(:consider_all_requests_local? => false, :local_request? => false)
    get :properties
    assert_select 'p'
  end

  test "info controller allows requests when all requests are considered local" do
    @controller.stubs(:consider_all_requests_local? => true, :local_request? => false)
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
