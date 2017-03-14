require "rails/generators"

module Rails
  module Command
    class DestroyCommand < Base # :nodoc:
      no_commands do
        def help
          Rails::Generators.help self.class.command_name
        end
      end

      def perform(*)
        generator = args.shift
        return help unless generator

        require_application_and_environment!
        load_generators

        Rails::Generators.invoke generator, args, behavior: :revoke, destination_root: Rails::Command.root
      end
    end
  end
end
