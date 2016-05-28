require "rails/command"
require "rails/test_unit/minitest_plugin"

module Rails
  module Command
    class TestCommand < Base
      def help # :nodoc:
        perform # Hand over help printing to minitest.
      end

      def perform(*)
        $LOAD_PATH << Rails::Command.root.join("test")

        exit Minitest.run(ARGV)
      end
    end
  end
end
