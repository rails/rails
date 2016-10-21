require "rails/command"
require "rails/test_unit/minitest_plugin"
require "rails/test_unit/line_filtering"

module Rails
  module Command
    class TestCommand < Base
      def help # :nodoc:
        perform # Hand over help printing to minitest.
      end

      def perform(*)
        $LOAD_PATH << Rails::Command.root.join("test")

        # Add test line filtering support for running test by line number
        # via the command line.
        ActiveSupport::TestCase.extend Rails::LineFiltering

        Minitest.run_via[:rails] = true

        require "active_support/testing/autorun"
      end
    end
  end
end
