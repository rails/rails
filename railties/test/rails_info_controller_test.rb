$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/controllers"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'action_controller'
require 'action_controller/test_process'
require 'rails_info'

module Controllers; def self.const_available?(constant); false end end

class ApplicationController < ActionController::Base
  @local_request = false
  class << self
    cattr_accessor :local_request
  end
  
protected
  def local_request?
    self.class.local_request
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

require 'rails_info_controller'

# Re-raise errors caught by the controller.
class Controllers::RailsInfoController; def rescue_action(e) raise e end; end

class RailsInfoControllerTest < Test::Unit::TestCase
  def setup
    @controller = Controllers::RailsInfoController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_rails_info_properties_table_rendered_for_local_request
    Controllers::RailsInfoController.local_request = true
    get :properties
    assert_tag :tag => 'table'
    assert_response :success
  end
  
  def test_rails_info_properties_error_rendered_for_non_local_request
    Controllers::RailsInfoController.local_request = false
    get :properties
    assert_tag :tag => 'p'
    assert_response 500
  end
end
