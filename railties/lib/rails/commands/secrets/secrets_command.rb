# frozen_string_literal: true

require "active_support"
require "rails/secrets"
require "rails/command/helpers/editor"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      desc "edit", "**deprecated** Open the secrets in `$VISUAL` or `$EDITOR` for editing"
      def edit
        Rails.deprecator.warn(<<~MSG.squish)
          `bin/rails secrets:edit` is deprecated in favor of credentials and will be removed in Rails 7.2.
          Run `bin/rails credentials:help` for more information.
        MSG

        boot_application!

        using_system_editor do
          Rails::Secrets.read_for_editing { |tmp_path| system_editor(tmp_path) }
          say "File encrypted and saved."
        end
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      rescue Errno::ENOENT => error
        if error.message.include?("secrets.yml.enc")
          exit 1
        else
          raise
        end
      end

      desc "show", "**deprecated** Show the decrypted secrets"
      def show
        Rails.deprecator.warn(<<~MSG.squish)
          `bin/rails secrets:show` is deprecated in favor of credentials and will be removed in Rails 7.2.
          Run `bin/rails credentials:help` for more information.
        MSG

        say Rails::Secrets.read
      end
    end
  end
end
