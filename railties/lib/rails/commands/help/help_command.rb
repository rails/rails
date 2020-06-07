# frozen_string_literal: true

module Rails
  module Command
    class HelpCommand < Base # :nodoc:
      hide_command!

      def help(*)
        say self.class.desc

        other_commands = printing_commands_not_in_usage.sort_by(&:first)
        print_table(other_commands, indent: 1, truncate: true)
      end

      private
        COMMANDS_IN_USAGE = %w(generate console server test test:system dbconsole new)
        private_constant :COMMANDS_IN_USAGE

        def printing_commands_not_in_usage # :nodoc:
          Rails::Command.printing_commands.reject do |command, _|
            command.in?(COMMANDS_IN_USAGE)
          end
        end
    end
  end
end
