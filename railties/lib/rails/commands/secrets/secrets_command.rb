# frozen_string_literal: true

require "active_support"
require "rails/secrets"
require "rails/command/helpers/editor"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def setup
        deprecate_in_favor_of_credentials_and_exit
      end

      def edit
        require_application_and_environment!

        using_system_editor do
          Rails::Secrets.read_for_editing { |tmp_path| system_editor(tmp_path) }
          say "File encrypted and saved."
        end
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      rescue Errno::ENOENT => error
        if /secrets\.yml\.enc/.match?(error.message)
          deprecate_in_favor_of_credentials_and_exit
        else
          raise
        end
      end

      def show
        say Rails::Secrets.read
      end

      private
        def deprecate_in_favor_of_credentials_and_exit
          say "Encrypted secrets is deprecated in favor of credentials. Run:"
          say "bin/rails credentials:help"

          exit 1
        end
    end
  end
end
