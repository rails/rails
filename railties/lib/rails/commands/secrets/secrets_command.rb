# frozen_string_literal: true

require "active_support"
require "rails/secrets"
require "rails/command/helpers/editor"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      desc "setup", "Deprecated in favor of credentials -- run `bin/rails credentials:help`"
      def setup
        deprecate_in_favor_of_credentials_and_exit
      end

      desc "edit", "Open the secrets in `$EDITOR` for editing"
      def edit
        boot_application!

        using_system_editor do
          Rails::Secrets.read_for_editing { |tmp_path| system_editor(tmp_path) }
          say "File encrypted and saved."
        end
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      rescue Errno::ENOENT => error
        if error.message.include?("secrets.yml.enc")
          deprecate_in_favor_of_credentials_and_exit
        else
          raise
        end
      end

      desc "show", "Show the decrypted secrets"
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
