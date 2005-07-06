ENV["RAILS_ENV"] = "test"
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../actionpack/lib')
$:.unshift(File.dirname(__FILE__) + '/../../activerecord/lib')

require 'test/unit'
require 'active_record'
require 'action_web_service'
require 'action_controller'
require 'action_controller/test_process'

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = true
