require 'abstract_unit'
require 'action_controller'
require 'action_controller/test_case'

RAILS_ENV = "test"
CURRENT_DIR = File.expand_path(File.dirname(__FILE__))
HTML_DIR = File.expand_path(File.join(CURRENT_DIR, "..", "html"))

module Rails
  def self.public_path
    CURRENT_DIR
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

class ErrorPageControllerTest < ActionController::TestCase
  def setup
    ActionController::Base.consider_all_requests_local = false
    rescue_action_in_public!
  end

  def test_500_error_page_instructs_system_administrator_to_check_log_file
    template = ERB.new(File.read(File.join(HTML_DIR, "500.html")))
    File.open(File.join(CURRENT_DIR, "500.html"), "w") do |f|
      f.write(template.result)
    end
    get :crash
    expected_log_file = "#{RAILS_ENV}.log"
    assert_not_nil @response.body.index(expected_log_file), @response.body
  end
end
