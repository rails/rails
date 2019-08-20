# frozen_string_literal: true

module Rails
  module Command
    class HelpCommand < Base # :nodoc:
      hide_command!

      def help(*)
        say self.class.desc

        Rails::Command.print_commands
      end
    end
  end
end
