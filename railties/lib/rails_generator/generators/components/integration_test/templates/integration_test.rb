require "#{File.dirname(__FILE__)}<%= '/..' * class_nesting_depth %>/../test_helper"

class <%= class_name %>Test < ActionController::IntegrationTest
end
