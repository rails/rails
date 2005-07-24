$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')

require 'test/unit'
require 'action_controller'

require 'action_controller/test_process'

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = false
ActionController::Routing::Routes.reload rescue nil

