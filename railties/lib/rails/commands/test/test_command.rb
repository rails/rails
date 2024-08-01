# frozen_string_literal: true

require "rails/command"
require "rails/commands/rake/rake_command"
require "rails/test_unit/runner"
require "rails/test_unit/reporter"

module Rails
  module Command
    class TestCommand < Base # :nodoc:
      def self.executable(*args)
        args.empty? ? Rails::TestUnitReporter.executable : super
      end

      no_commands do
        def help(command_name = nil, *)
          super
          if command_name == "test"
            say ""
            say self.class.class_usage
          end
          say ""
          Minitest.run(%w(--help))
        end
      end

      desc "test [PATHS...]", "Run tests except system tests"
      def perform(*args)
        $LOAD_PATH << Rails::Command.root.join("test").to_s

        Rails::TestUnit::Runner.parse_options(args)
        run_prepare_task if self.args.none?(EXACT_TEST_ARGUMENT_PATTERN)
        Rails::TestUnit::Runner.run(args)
      rescue Rails::TestUnit::InvalidTestError => error
        raise ArgumentError, error.message
      end

      # Define Thor tasks to avoid going through Rake and booting twice when using bin/rails test:*
      Rails::TestUnit::Runner::TEST_FOLDERS.each do |name|
        desc name, "Run tests in test/#{name}"
        define_method(name) do |*args|
          perform("test/#{name}", *args)
        end
      end

      desc "all", "Run all tests, including system tests"
      def all(*args)
        perform("test/**/*_test.rb", *args)
      end

      desc "functionals", "Run tests in test/controllers, test/mailers, and test/functional"
      def functionals(*args)
        perform("test/controllers", "test/mailers", "test/functional", *args)
      end

      desc "units", "Run tests in test/models, test/helpers, and test/unit"
      def units(*args)
        perform("test/models", "test/helpers", "test/unit", *args)
      end

      desc "system", "Run system tests only"
      def system(*args)
        perform("test/system", *args)
      end

      desc "generators", "Run tests in test/lib/generators"
      def generators(*args)
        perform("test/lib/generators", *args)
      end

      private
        EXACT_TEST_ARGUMENT_PATTERN = /^-n|^--name\b|#{Rails::TestUnit::Runner::PATH_ARGUMENT_PATTERN}/

        def run_prepare_task
          Rails::Command::RakeCommand.perform("test:prepare", [], {})
        rescue UnrecognizedCommandError => error
          raise unless error.name == "test:prepare"
        end
    end
  end
end
