$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../lib/action_web_service/vendor')

require 'test/unit'
require 'action_web_service'
require 'action_controller'
require 'action_controller/test_process'

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = true
