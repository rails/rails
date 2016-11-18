$: << File.expand_path("test", COMPONENT_ROOT)

require "bundler"
Bundler.setup

require "rails/test_unit/minitest_plugin"

module Rails
  # Necessary to get rerun-snippts working.
  def self.root
    @root ||= Pathname.new(COMPONENT_ROOT)
  end
end

Rails::TestUnitReporter.executable = "bin/test"
