require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'action_mailer'

$:.unshift "#{File.dirname(__FILE__)}/fixtures/helpers"
ActionMailer::Base.template_root = "#{File.dirname(__FILE__)}/fixtures"
