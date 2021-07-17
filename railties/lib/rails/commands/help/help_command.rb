# frozen_string_literal: true

module Rails
  module Command
    class HelpCommand < Base # :nodoc:
      hide_command!

      def help(*)
        say self.class.desc
      end

      def help_extended(*)
        say self.class.desc

        say "In addition to those commands, there are:"
        Rails::Command.print_extended_commands
      end
    end
  end
end
