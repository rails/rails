require 'abstract_unit'
require 'action_controller'
require 'action_controller/test_process'

RAILS_ENV = "test"

module Rails
  def self.public_path
    File.expand_path(File.join(File.dirname(__FILE__), "..", "html"))
  end
end

class ErrorPageController < ActionController::Base
  def crash
    raise StandardError, "crash!"
  end
end

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

class ErrorPageControllerTest < Test::Unit::TestCase
  def setup
    @controller = ErrorPageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    ActionController::Base.consider_all_requests_local = false
  end

  def test_500_error_page_instructs_system_administrator_to_check_log_file
    get :crash
    expected_log_file = "#{RAILS_ENV}.log"
    assert_not_nil @response.body.index(expected_log_file)
  end
end
