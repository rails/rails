# frozen_string_literal: true

$: << File.expand_path("test", COMPONENT_ROOT)

require "bundler"
Bundler.setup

require "rails/test_unit/runner"
require "rails/test_unit/reporter"
require "rails/test_unit/line_filtering"
require "active_support"
require "active_support/test_case"

ActiveSupport::TestCase.extend Rails::LineFiltering
Rails::TestUnitReporter.executable = "bin/test"

Rails::TestUnit::Runner.parse_options(ARGV)
Rails::TestUnit::Runner.run(ARGV)
