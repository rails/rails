# frozen_string_literal: true

require "pathname"
require "active_support"
require "rails/command/helpers/editor"

module Rails
  module Command
    class EncryptedCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      class_option :key, aliases: "-k", type: :string,
        default: "config/master.key", desc: "The Rails.root relative path to the encryption key"

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
        end
      end

      def edit(file_path)
        require_application_and_environment!

        ensure_editor_available(command: "bin/rails encrypted:edit") || (return)
        ensure_encryption_key_has_been_added(options[:key])
        ensure_encrypted_file_has_been_added(file_path, options[:key])

        catch_editing_exceptions do
          change_encrypted_file_in_system_editor(file_path, options[:key])
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{file_path}. Perhaps you passed the wrong key?"
      end

      def show(file_path)
        require_application_and_environment!
        encrypted = Rails.application.encrypted(file_path, key_path: options[:key])

        say encrypted.read.presence || missing_encrypted_message(key: encrypted.key, key_path: options[:key], file_path: file_path)
      end

      private
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
            "Missing '#{key_path}' to decrypt data. See bin/rails encrypted:help"
          else
            "File '#{file_path}' does not exist. Use bin/rails encrypted:edit #{file_path} to change that."
          end
        end
    end
  end
end
