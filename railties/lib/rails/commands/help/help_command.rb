module Rails
  module Command
    class HelpCommand < Base
      hide_command!

      def help(*)
        puts self.class.desc

        Rails::Command.print_commands
      end
    end
  end
end
