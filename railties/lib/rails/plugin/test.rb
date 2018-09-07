# frozen_string_literal: true

require "rails/test_unit/runner"
require "rails/test_unit/reporter"

Rails::TestUnitReporter.executable = "bin/test"

Rails::TestUnit::Runner.parse_options(ARGV)
Rails::TestUnit::Runner.run(ARGV)
