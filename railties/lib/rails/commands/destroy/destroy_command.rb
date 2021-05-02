# frozen_string_literal: true

require "rails/generators"

module Rails
  module Command
    class DestroyCommand < Base # :nodoc:
      no_commands do
        def help
          require_application_and_environment!
          load_generators

          Rails::Generators.help self.class.command_name
        end
      end

      def delete_css_file_generate_with_scaffold
        FileUtils.remove_file(Rails.root.join('app', 'assets', 'stylesheets', 'scaffolds.scss'),force=true)
      end

      def perform(*)
        generator = args.shift
        return help unless generator

        require_application_and_environment!
        load_generators

        Rails::Generators.invoke generator, args, behavior: :revoke, destination_root: Rails::Command.root
        delete_css_file_generate_with_scaffold
      end
    end
  end
end
