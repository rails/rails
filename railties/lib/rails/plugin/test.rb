require "rails/test_unit/minitest_plugin"

Rails::TestUnitReporter.executable = "bin/test"

Minitest.run_via = :rails

require "active_support/testing/autorun"
