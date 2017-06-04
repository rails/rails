$: << File.expand_path("test", COMPONENT_ROOT)

require "bundler"
Bundler.setup

require "rails/test_unit/minitest_plugin"
require "rails/test_unit/line_filtering"
require "active_support/test_case"

class << Rails
  # Necessary to get rerun-snippts working.
  def root
    @root ||= Pathname.new(COMPONENT_ROOT)
  end
  alias __root root
end

ActiveSupport::TestCase.extend Rails::LineFiltering
Rails::TestUnitReporter.executable = "bin/test"
Minitest.run_via = :rails
require "active_support/testing/autorun"
