# frozen_string_literal: true

require "active_support"
require "rails/command/helpers/editor"
require "rails/command/helpers/pretty_credentials"
require "rails/command/environment_argument"
require "pathname"

module Rails
  module Command
    class CredentialsCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor
      include Helpers::PrettyCredentials
      include EnvironmentArgument

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

        catch_editing_exceptions do
          change_credentials_in_system_editor
        end

        say "File encrypted and saved."
        opt_in_pretty_credentials
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show(git_textconv_path = nil)
        if git_textconv_path
          default_environment = extract_environment_from_path(git_textconv_path)
          fallback_message = File.read(git_textconv_path)
        end

        extract_environment_option_from_argument(default_environment: default_environment)
        require_application!

        say credentials(git_textconv_path).read.presence || fallback_message || missing_credentials_message
      rescue => e
        raise(e) unless git_textconv_path
        fallback_message
      end

      private
        def credentials(content = nil)
          Rails.application.encrypted(content || content_path, key_path: key_path)
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

        def extract_environment_from_path(path)
          regex = %r{
            ([A-Za-z0-9]+)     # match the environment
            (?<!credentials)   # don't match if file contains the word "credentials"
                               # in such case, the environment should be the default one
            \.yml\.enc         # look for `.yml.enc` file extension
          }x
          path.match(regex)

          Regexp.last_match(1)
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
