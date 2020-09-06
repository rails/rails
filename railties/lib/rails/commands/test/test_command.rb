# frozen_string_literal: true

require 'rails/command'
require 'rails/test_unit/runner'
require 'rails/test_unit/reporter'

module Rails
  module Command
    class TestCommand < Base # :nodoc:
      no_commands do
        def help
          say "Usage: #{Rails::TestUnitReporter.executable} [options] [files or directories]"
          say ''
          say 'You can run a single test by appending a line number to a filename:'
          say ''
          say "    #{Rails::TestUnitReporter.executable} test/models/user_test.rb:27"
          say ''
          say 'You can run multiple files and directories at the same time:'
          say ''
          say "    #{Rails::TestUnitReporter.executable} test/controllers test/integration/login_test.rb"
          say ''
          say 'By default test failures and errors are reported inline during a run.'
          say ''

          Minitest.run(%w(--help))
        end
      end

      def perform(*)
        $LOAD_PATH << Rails::Command.root.join('test').to_s

        Rails::TestUnit::Runner.parse_options(args)
        Rails::TestUnit::Runner.run(args)
      end
    end
  end
end
