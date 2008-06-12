require 'abstract_unit'
require 'action_controller'
require 'action_controller/test_process'

module Rails; end
require 'rails/info'
require 'rails/info_controller'

class Rails::InfoController < ActionController::Base
  @local_request = false
  class << self
    cattr_accessor :local_request
  end
  
  # Re-raise errors caught by the controller.
  def rescue_action(e) raise e end;
  
protected
  def local_request?
    self.class.local_request
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

class Rails::InfoControllerTest < Test::Unit::TestCase
  def setup
    @controller = Rails::InfoController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    ActionController::Base.consider_all_requests_local = true
  end

  def test_rails_info_properties_table_rendered_for_local_request
    Rails::InfoController.local_request = true
    get :properties
    assert_tag :tag => 'table'
    assert_response :success
  end
  
  def test_rails_info_properties_error_rendered_for_non_local_request
    Rails::InfoController.local_request = false
    ActionController::Base.consider_all_requests_local = false

    get :properties
    assert_tag :tag => 'p'
    assert_response 500
  end
end
