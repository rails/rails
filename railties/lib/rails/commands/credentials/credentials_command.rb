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
        require_application_and_environment!

        ensure_editor_available(command: "bin/rails credentials:edit") || (return)

        encrypted = Rails.application.encrypted(content_path, key_path: key_path)

        ensure_encryption_key_has_been_added(key_path) if encrypted.key.nil?
        ensure_encrypted_file_has_been_added(content_path, key_path)

        catch_editing_exceptions do
          change_encrypted_file_in_system_editor(content_path, key_path)
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show
        require_application_and_environment!

        encrypted = Rails.application.encrypted(content_path, key_path: key_path)

        say encrypted.read.presence || missing_encrypted_message(key: encrypted.key, key_path: key_path, file_path: content_path)
      end

      private
        def content_path
          options[:environment] ? "config/credentials/#{options[:environment]}.yml.enc" : "config/credentials.yml.enc"
        end

        def key_path
          options[:environment] ? "config/credentials/#{options[:environment]}.key" : "config/master.key"
        end


        def ensure_encryption_key_has_been_added(key_path)
          encryption_key_file_generator.add_key_file(key_path)
          encryption_key_file_generator.ignore_key_file(key_path)
        end

        def ensure_encrypted_file_has_been_added(file_path, key_path)
          encrypted_file_generator.add_encrypted_file_silently(file_path, key_path)
        end

        def change_encrypted_file_in_system_editor(file_path, key_path)
          Rails.application.encrypted(file_path, key_path: key_path).change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
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

        def missing_encrypted_message(key:, key_path:, file_path:)
          if key.nil?
            "Missing '#{key_path}' to decrypt credentials. See `rails credentials:help`"
          else
            "File '#{file_path}' does not exist. Use `rails credentials:edit` to change that."
          end
        end
    end
  end
end
