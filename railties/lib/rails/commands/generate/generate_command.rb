# frozen_string_literal: true

module Rails
  module Command
    class GenerateCommand < Base # :nodoc:
      no_commands do
        def help
          boot_application!
          load_generators

          Rails::Generators.help self.class.command_name
        end
      end

      def perform(*)
        require "rails/generators"
        generator = args.shift
        return help unless generator

        boot_application!
        load_generators

        ARGV.replace(args) # set up ARGV for third-party libraries

        Rails::Generators.invoke generator, args, behavior: :invoke, destination_root: Rails::Command.root
      end
    end
  end
end
