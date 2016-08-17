module Rails
  module CommonCommandsTasks # :nodoc:
    def run_command!(command)
      command = parse_command(command)

      if command_whitelist.include?(command)
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
      argv.unshift "--version"
      require_command!("application")
    end

    def help
      write_help_message
      write_commands(commands)
    end

    private

      def generate_or_destroy(command)
        require "rails/generators"
        require_application_and_environment!
        load_generators
        require_command!(command)
      end

      def require_command!(command)
        require "rails/commands/#{command}"
      end

      def write_help_message
        puts help_message
      end

      def write_commands(commands)
        width = commands.map { |name, _| name.size }.max || 10
        commands.each { |command| printf(" %-#{width}s   %s\n", *command) }
      end

      def parse_command(command)
        case command
        when "--version", "-v"
          "version"
        when "--help", "-h"
          "help"
        else
          command
        end
      end
  end
end
