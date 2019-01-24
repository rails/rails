# frozen_string_literal: true

require "active_support"
require "rails/command/helpers/editor"

module Rails
  module Command
    class CredentialsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      class_option :environment, aliases: "-e", type: :string,
        desc: "Uses credentials from config/credentials/:environment.yml.enc encrypted by config/credentials/:environment.key key"

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def edit
        require_application!

        ensure_editor_available(command: "bin/rails credentials:edit") || (return)

        ensure_encryption_key_has_been_added if credentials.key.nil?
        ensure_credentials_have_been_added

        catch_editing_exceptions do
          change_credentials_in_system_editor
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show
        require_application!

        say credentials.read.presence || missing_credentials_message
      end

      private
        def credentials
          Rails.application.encrypted(content_path, key_path: key_path)
        end

        def ensure_encryption_key_has_been_added
          encryption_key_file_generator.add_key_file(key_path)
          encryption_key_file_generator.ignore_key_file(key_path)
        end

        def ensure_credentials_have_been_added
          encrypted_file_generator.add_encrypted_file_silently(content_path, key_path)
        end

        def change_credentials_in_system_editor
          credentials.change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end

        def missing_credentials_message
          if credentials.key.nil?
            "Missing '#{key_path}' to decrypt credentials. See `rails credentials:help`"
          else
            "File '#{content_path}' does not exist. Use `rails credentials:edit` to change that."
          end
        end


        def content_path
          options[:environment] ? "config/credentials/#{options[:environment]}.yml.enc" : "config/credentials.yml.enc"
        end

        def key_path
          options[:environment] ? "config/credentials/#{options[:environment]}.key" : "config/master.key"
        end


        def encryption_key_file_generator
          require "rails/generators"
          require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"

          Rails::Generators::EncryptionKeyFileGenerator.new
        end

        def encrypted_file_generator
          require "rails/generators"
          require "rails/generators/rails/encrypted_file/encrypted_file_generator"

          Rails::Generators::EncryptedFileGenerator.new
        end
    end
  end
end
