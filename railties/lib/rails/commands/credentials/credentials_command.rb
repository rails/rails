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
        ENV["RAILS_ENV"] = environment # Ensures that Rails.configuration is initialized using the right env
        require_application!

        ensure_editor_available(command: "bin/rails credentials:edit") || (return)

        ensure_encryption_key_has_been_added if credentials.key.nil?
        ensure_credentials_have_been_added
        ensure_rails_credentials_driver_is_set

        catch_editing_exceptions do
          change_credentials_in_system_editor
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show
        extract_environment_option_from_argument(default_environment: nil)
        ENV["RAILS_ENV"] = environment # Ensures that Rails.configuration is initialized using the right env
        require_application!

        say credentials.read.presence || missing_credentials_message
      end

      option :enroll, type: :boolean, default: false,
        desc: "Enrolls project in credential file diffing with `git diff`"

      def diff(content_path = nil)
        if @content_path = content_path
          extract_environment_option_from_argument(default_environment: extract_environment_from_path(content_path))
          require_application!

          say credentials.read.presence || credentials.content_path.read
        else
          require_application!
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
          if environment_specified?
            encrypted_file_generator.add_encrypted_file_silently(content_path, key_path)
          else
            credentials_generator.add_credentials_file_silently(config_path: content_path, key_path: key_path)
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
          @content_path ||= determine_path(:content_path,
                                           default_path: "config/credentials.yml.enc",
                                           env_path: "config/credentials/#{environment}.yml.enc")
        end

        def key_path
          @key_path ||= determine_path(:key_path,
                                       default_path: "config/master.key",
                                       env_path: "config/credentials/#{environment}.key")
        end

        def determine_path(which, default_path:, env_path:)
          load_environment_config if environment_specified?
          config_path = Rails.application.config.credentials[which].to_s.gsub(Rails.root.to_s + "/", "")

          if environment_specified?
            # Rails.configuration initializes credentials paths based on the existence of credentials files. So,
            # config_path is the same as default_path when credentials don't yet exist for the specified environment
            # (happens the first time credentials:edit -e $environment is invoked). We don't want the default path
            # when an environment has been specified though, so only return config_path if it has been changed by the
            # user. Otherwise, return env_path.
            return config_path if config_path != default_path
            env_path
          else
            # Rails.configuration initializes credentials paths based on the existence of credentials files.
            # Furthermore, Rails and its configuration default to the "development" environment when no environment is
            # specified, unlike the credentials command, which can run without an environment to edit shared files.
            # config_path is the same as env_path when credentials already exist for the specified environment, which,
            # according to Rails.configuration, will be development even if no environment is specified for the
            # credentials command. We don't want the environment-based path when no environment option was given though,
            # so only return config_path if it has been changed by the user. Otherwise, return default_path.
            return config_path if config_path != env_path
            default_path
          end
        end

        def extract_environment_from_path(path)
          available_environments.find { |env| path.include? env } if path.end_with?(".yml.enc")
        end

        def environment
          # Explicitly keep credentials env in sync with Rails env, which defaults to dev
          options[:environment] || "development"
        end

        def environment_specified?
          options[:environment].present?
        end

        def load_environment_config
          path = Rails.root.join("config/environments/#{environment}.rb")
          require(path) if File.exist?(path)
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
