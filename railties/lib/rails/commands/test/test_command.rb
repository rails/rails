require_relative "../../command"
require_relative "../../test_unit/runner"

module Rails
  module Command
    class TestCommand < Base # :nodoc:
      no_commands do
        def help
          require "optparse"
          require "minitest/rails_plugin"

          opts = OptionParser.new
          opts.banner = "Usage: #{Rails::TestUnitReporter.executable} [options] [files or directories]"
          opts.separator ""
          opts.separator "You can run a single test by appending a line number to a filename:"
          opts.separator ""
          opts.separator "    #{Rails::TestUnitReporter.executable} test/models/user_test.rb:27"
          opts.separator ""
          opts.separator "You can run multiple files and directories at the same time:"
          opts.separator ""
          opts.separator "    #{Rails::TestUnitReporter.executable} test/controllers test/integration/login_test.rb"
          opts.separator ""
          opts.separator "By default test failures and errors are reported inline during a run."
          opts.separator ""

          opts.separator "Rails options:"
          Rails::TestUnit::Runner.options(opts)
          Minitest.plugin_rails_options(opts, {})

          say opts
        end
      end

      def perform(*)
        $LOAD_PATH << Rails::Command.root.join("test").to_s

        Rails::TestUnit::Runner.parse_options(ARGV)
        Rails::TestUnit::Runner.run(ARGV)
      end
    end
  end
end
