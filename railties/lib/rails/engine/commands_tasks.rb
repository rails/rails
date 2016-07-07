require 'rails/commands/rake_proxy'

module Rails
  class Engine
    class CommandsTasks # :nodoc:
      include Rails::RakeProxy

      attr_reader :argv

      HELP_MESSAGE = <<-EOT
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

      COMMAND_WHITELIST = %w(generate destroy version help test)

      def initialize(argv)
        @argv = argv
      end

      def run_command!(command)
        command = parse_command(command)

        if COMMAND_WHITELIST.include?(command)
          send(command)
        else
          run_rake_task(command)
        end
      end

      def generate
        generate_or_destroy(:generate)
      end

      def destroy
        generate_or_destroy(:destroy)
      end

      def test
        require_command!("test")
      end

      def version
        argv.unshift '--version'
        require_command!("application")
      end

      def help
        write_help_message
        write_commands(formatted_rake_tasks)
      end

      private

        def require_command!(command)
          require "rails/commands/#{command}"
        end

        def generate_or_destroy(command)
          load_generators
          require_command!(command)
        end

        def load_generators
          require 'rails/generators'
          require ENGINE_PATH

          engine = ::Rails::Engine.find(ENGINE_ROOT)
          Rails::Generators.namespace = engine.railtie_namespace
          engine.load_generators
        end

        def write_help_message
          puts HELP_MESSAGE
        end

        def write_commands(commands)
          width = commands.map { |name, _| name.size }.max || 10
          commands.each { |command| printf(" %-#{width}s   %s\n", *command) }
        end

        def parse_command(command)
          case command
          when '--version', '-v'
            'version'
          when '--help', '-h'
            'help'
          else
            command
          end
        end

        def rake_tasks
          return @rake_tasks if defined?(@rake_tasks)

          load_generators
          Rake::TaskManager.record_task_metadata = true
          Rake.application.init('rails')
          Rake.application.load_rakefile
          @rake_tasks = Rake.application.tasks.select(&:comment)
        end
    end
  end
end
