# frozen_string_literal: true

require "pathname"
require "active_support"
require "rails/command/helpers/editor"
require "rails/command/environment_argument"

module Rails
  module Command
    class CredentialsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor
      include EnvironmentArgument

      require_relative "credentials_command/diffing"
      include Diffing

      self.environment_desc = "Uses credentials from config/credentials/:environment.yml.enc encrypted by config/credentials/:environment.key key"

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def edit
        extract_environment_option_from_argument(default_environment: nil)
        require_application!

        ensure_editor_available(command: "bin/rails credentials:edit") || (return)

        ensure_encryption_key_has_been_added if credentials.key.nil?
        ensure_credentials_have_been_added
        ensure_diffing_driver_is_configured

        catch_editing_exceptions do
          change_credentials_in_system_editor
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show
        extract_environment_option_from_argument(default_environment: nil)
        require_application!

        say credentials.read.presence || missing_credentials_message
      end

      option :enroll, type: :boolean, default: false,
        desc: "Enrolls project in credentials file diffing with `git diff`"

      option :disenroll, type: :boolean, default: false,
        desc: "Disenrolls project from credentials file diffing"

      def diff(content_path = nil)
        if @content_path = content_path
          extract_environment_option_from_argument(default_environment: extract_environment_from_path(content_path))
          require_application!

          say credentials.read.presence || credentials.content_path.read
        else
          require_application!
          disenroll_project_from_credentials_diffing if options[:disenroll]
          enroll_project_in_credentials_diffing if options[:enroll]
        end
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say credentials.content_path.read
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
          if options[:environment]
            encrypted_file_generator.add_encrypted_file_silently(content_path, key_path)
          else
            credentials_generator.add_credentials_file_silently
          end
        end

        def change_credentials_in_system_editor
          credentials.change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end

        def missing_credentials_message
          if credentials.key.nil?
            "Missing '#{key_path}' to decrypt credentials. See `bin/rails credentials:help`"
          else
            "File '#{content_path}' does not exist. Use `bin/rails credentials:edit` to change that."
          end
        end

        def content_path
          @content_path ||= options[:environment] ? "config/credentials/#{options[:environment]}.yml.enc" : "config/credentials.yml.enc"
        end

        def key_path
          options[:environment] ? "config/credentials/#{options[:environment]}.key" : "config/master.key"
        end

        def extract_environment_from_path(path)
          available_environments.find { |env| path.include? env } if path.end_with?(".yml.enc")
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

        def credentials_generator
          require "rails/generators"
          require "rails/generators/rails/credentials/credentials_generator"

          Rails::Generators::CredentialsGenerator.new
        end
    end
  end
end
