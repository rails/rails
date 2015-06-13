$: << File.expand_path("test", COMPONENT_ROOT)
require File.expand_path("../../load_paths", __FILE__)
require "rails/test_unit/minitest_plugin"

module Rails
  # Necessary to get rerun-snippts working.
  def self.root
    @root ||= Pathname.new(COMPONENT_ROOT)
  end
end

Rails::TestUnitReporter.executable = "bin/test"
