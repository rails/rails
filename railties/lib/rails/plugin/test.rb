require_relative "../test_unit/runner"
require_relative "../test_unit/reporter"

Rails::TestUnitReporter.executable = "bin/test"

Rails::TestUnit::Runner.parse_options(ARGV)
Rails::TestUnit::Runner.run(ARGV)
