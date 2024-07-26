$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'action_controller'

require 'action_controller/test_process'

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = true