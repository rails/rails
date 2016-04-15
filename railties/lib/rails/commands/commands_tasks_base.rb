require 'rails/commands/rake_proxy'

module Rails
  # This is a class which takes in a rails command and initiates the appropriate
  # initiation sequence.
  #
  # Warning: This class mutates ARGV because some commands require manipulating
  # it before they are run.
  class CommandsTasksBase # :nodoc:
    include Rails::RakeProxy

    attr_reader :argv

    def initialize(argv)
      @argv = argv
    end

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
      argv.unshift '--version'
      require_command!("application")
    end

    private

      def require_command!(command)
        require "rails/commands/#{command}"
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
  end
end
