require "rails/commands/rake_proxy"
require "rails/commands/common_commands_tasks"
require "active_support/core_ext/string/strip"

module Rails
  class Engine
    class CommandsTasks # :nodoc:
      include Rails::RakeProxy
      include Rails::CommonCommandsTasks

      attr_reader :argv

      def initialize(argv)
        @argv = argv
      end

      private

        def commands
          formatted_rake_tasks
        end

        def command_whitelist
          %w(generate destroy version help test)
        end

        def help_message
          <<-EOT.strip_heredoc
            Usage: rails COMMAND [ARGS]

            The common Rails commands available for engines are:
             generate    Generate new code (short-cut alias: "g")
             destroy     Undo code generated with "generate" (short-cut alias: "d")
             test        Run tests (short-cut alias: "t")

            All commands can be run with -h for more information.

            If you want to run any commands that need to be run in context
            of the application, like `rails server` or `rails console`,
            you should do it from application's directory (typically test/dummy).

            In addition to those commands, there are:
          EOT
        end

        def require_application_and_environment!
          require ENGINE_PATH
        end

        def load_tasks
          Rake.application.init("rails")
          Rake.application.load_rakefile
        end

        def load_generators
          engine = ::Rails::Engine.find(ENGINE_ROOT)
          Rails::Generators.namespace = engine.railtie_namespace
          engine.load_generators
        end
    end
  end
end
