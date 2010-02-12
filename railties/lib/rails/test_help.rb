# Make double-sure the RAILS_ENV is set to test,
# so fixtures are loaded to the right database
exit("Abort testing: Your Rails environment is not running in test mode!") unless Rails.env.test?

require 'test/unit'
require 'active_support/core_ext/kernel/requires'

# TODO: Figure out how to get the Rails::BacktraceFilter into minitest/unit
if defined?(Test::Unit::Util::BacktraceFilter) && ENV['BACKTRACE'].nil?
  require 'rails/backtrace_cleaner'
  Test::Unit::Util::BacktraceFilter.module_eval { include Rails::BacktraceFilterForTestUnit }
end

if defined?(ActiveRecord)
  class ActiveSupport::TestCase
    include ActiveRecord::TestFixtures
    self.fixture_path = "#{Rails.root}/test/fixtures/"
  end

  ActionController::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path

  def create_fixtures(*table_names, &block)
    Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names, {}, &block)
  end
end

begin
  require_library_or_gem 'ruby-debug'
  Debugger.start
  if Debugger.respond_to?(:settings)
    Debugger.settings[:autoeval] = true
    Debugger.settings[:autolist] = 1
  end
rescue LoadError
  # ruby-debug wasn't available so neither can the debugging be
end
