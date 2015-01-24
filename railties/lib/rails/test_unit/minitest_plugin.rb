require "minitest"
require "rails/test_unit/reporter"

def Minitest.plugin_rails_init(options)
  self.reporter << Rails::TestUnitReporter.new(options[:io], options)
  if $rails_test_runner && (method = $rails_test_runner.find_method)
    options[:filter] = method
  end

  if ENV["BACKTRACE"].nil? && !($rails_test_runner && $rails_test_runner.show_backtrace?)
    Minitest.backtrace_filter = Rails.backtrace_cleaner
  end
end
Minitest.extensions << 'rails'

