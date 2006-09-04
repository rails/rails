ENV["RAILS_ENV"] = "test"
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../actionpack/lib')
$:.unshift(File.dirname(__FILE__) + '/../../activerecord/lib')

require 'test/unit'
require 'action_web_service'
require 'action_controller'
require 'action_controller/test_process'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true


ActionController::Base.logger = Logger.new("debug.log")
ActionController::Base.ignore_missing_templates = true

begin
  PATH_TO_AR = File.dirname(__FILE__) + '/../../activerecord'
  require "#{PATH_TO_AR}/lib/active_record" unless Object.const_defined?(:ActiveRecord)
  require "#{PATH_TO_AR}/lib/active_record/fixtures" unless Object.const_defined?(:Fixtures)
rescue LoadError => e
  fail "\nFailed to load activerecord: #{e}"
end

ActiveRecord::Base.configurations = {
  'mysql' => {
    :adapter  => "mysql",
    :username => "rails",
    :encoding => "utf8",
    :database => "actionwebservice_unittest"
  }
}

ActiveRecord::Base.establish_connection 'mysql'

Test::Unit::TestCase.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"

# restore default raw_post functionality
class ActionController::TestRequest
  def raw_post
    super
  end
end
