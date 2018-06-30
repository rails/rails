# frozen_string_literal: true

require "active_support"
require "rails/command/helpers/editor"

module Rails
  module Command
    class CredentialsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def edit
        require_application_and_environment!

        ensure_editor_available(command: "bin/rails credentials:edit") || (return)

        if Rails.application.credentials.content_path.exist? && Rails.application.credentials.key.nil?
          say "Encrypted credentials already exist but master key is missing."
          say "Put master key to decrypt the encrypted."
          return
        end

        ensure_master_key_has_been_added if Rails.application.credentials.key.nil?
        ensure_credentials_have_been_added

        catch_editing_exceptions do
          change_credentials_in_system_editor
        end

        say "New credentials encrypted and saved."
      end

      def show
        require_application_and_environment!

        say Rails.application.credentials.read.presence || missing_credentials_message
      end

      private
        def ensure_master_key_has_been_added
          master_key_generator.add_master_key_file
          master_key_generator.ignore_master_key_file
        end

        def ensure_credentials_have_been_added
          credentials_generator.add_credentials_file_silently
        end

        def change_credentials_in_system_editor
          Rails.application.credentials.change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end

        def master_key_generator
          require "rails/generators"
          require "rails/generators/rails/master_key/master_key_generator"

          Rails::Generators::MasterKeyGenerator.new
        end

        def credentials_generator
          require "rails/generators"
          require "rails/generators/rails/credentials/credentials_generator"

          Rails::Generators::CredentialsGenerator.new
        end

        def missing_credentials_message
          if Rails.application.credentials.key.nil?
            "Missing master key to decrypt credentials. See bin/rails credentials:help"
          else
            "No credentials have been added yet. Use bin/rails credentials:edit to change that."
          end
        end
    end
  end
end
