ENV["RAILS_ENV"] = "test"
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../actionpack/lib')
$:.unshift(File.dirname(__FILE__) + '/../../activerecord/lib')

require 'test/unit'
require 'action_web_service'
require 'action_controller'
require 'action_controller/test_process'

ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = true

begin
  PATH_TO_AR = File.dirname(__FILE__) + '/../../activerecord'
  require "#{PATH_TO_AR}/lib/active_record" unless Object.const_defined?(:ActiveRecord)
  require "#{PATH_TO_AR}/lib/active_record/fixtures" unless Object.const_defined?(:Fixtures)
rescue Object => e
  fail "\nFailed to load activerecord: #{e}"
end

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql",
  :username => "rails",
  :encoding => "utf8",
  :database => "activewebservice_unittest"
)
ActiveRecord::Base.connection

Test::Unit::TestCase.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"

# restore default raw_post functionality
class ActionController::TestRequest
  def raw_post
    super
  end
end