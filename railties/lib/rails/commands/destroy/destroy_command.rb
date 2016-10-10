require "rails/generators"

module Rails
  module Command
    class DestroyCommand < Base
      def help # :nodoc:
        Rails::Generators.help self.class.command_name
      end

      def perform(*)
        generator = args.shift
        return help unless generator

        require_application_and_environment!
        Rails.application.load_generators

        Rails::Generators.invoke generator, args, behavior: :revoke, destination_root: Rails.root
      end
    end
  end
end
