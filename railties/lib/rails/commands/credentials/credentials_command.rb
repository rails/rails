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

      desc "edit", "Open the decrypted credentials in `$VISUAL` or `$EDITOR` for editing"
      def edit
        load_environment_config!
        load_generators

        if environment_specified?
          @content_path = "config/credentials/#{environment}.yml.enc" unless config.overridden?(:content_path)
          @key_path = "config/credentials/#{environment}.key" unless config.overridden?(:key_path)
        end

        ensure_encryption_key_has_been_added
        ensure_credentials_have_been_added
        ensure_diffing_driver_is_configured

        change_credentials_in_system_editor
      end

      desc "show", "Show the decrypted credentials"
      def show
        load_environment_config!

        say credentials.read.presence || missing_credentials!
      end

      desc "diff", "Enroll/disenroll in decrypted diffs of credentials using git"
      option :enroll, type: :boolean, default: false,
        desc: "Enroll project in credentials file diffing with `git diff`"
      option :disenroll, type: :boolean, default: false,
        desc: "Disenroll project from credentials file diffing"
      def diff(content_path = nil)
        if @content_path = content_path
          self.environment = extract_environment_from_path(content_path)
          load_environment_config!

          say credentials.read.presence || credentials.content_path.read
        else
          disenroll_project_from_credentials_diffing if options[:disenroll]
          enroll_project_in_credentials_diffing if options[:enroll]
        end
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say credentials.content_path.read
      end

      desc "fetch PATH", "Fetch a value in the decrypted credentials"
      def fetch(path)
        load_environment_config!

        if (yaml = credentials.read)
          begin
            value = YAML.load(yaml)
            value = path.split(".").inject(value) do |doc, key|
              doc.fetch(key)
            end
            say value.to_s
          rescue KeyError, NoMethodError
            say_error "Invalid or missing credential path: #{path}"
            exit 1
          end
        else
          missing_credentials!
        end
      end

      desc "set KEY=VALUE", "Set a credential value (use dot notation for nesting, e.g. aws.access_key_id=VALUE)"
      def set(assignment)
        load_environment_config!
        load_generators

        unless assignment.include?("=")
          say_error "Expected argument in the form KEY=VALUE, got: #{assignment}"
          exit 1
        end

        key_path_str, value = assignment.split("=", 2)
        keys = key_path_str.split(".")

        if keys.any? { |k| k.empty? }
          say_error "Invalid key path: #{key_path_str}"
          exit 1
        end

        if environment_specified?
          @content_path = "config/credentials/#{environment}.yml.enc" unless config.overridden?(:content_path)
          @key_path = "config/credentials/#{environment}.key" unless config.overridden?(:key_path)
        end

        ensure_encryption_key_has_been_added
        ensure_credentials_have_been_added

        yaml = credentials.read.presence || ""
        parsed = YAML.load(yaml).presence || {}

        deep_set(parsed, keys, value)

        credentials.write(YAML.dump(parsed))
        say "#{key_path_str} was set."
      rescue ActiveSupport::EncryptedFile::MissingKeyError => error
        say error.message
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      desc "list", "List credential keys"
      option :show_values, type: :boolean, default: false,
        desc: "Show decrypted values alongside keys"
      def list
        load_environment_config!

        yaml = credentials.read.presence || missing_credentials!
        parsed = YAML.load(yaml).presence

        unless parsed
          say "No credentials found."
          return
        end

        flatten_keys(parsed).each do |key, value|
          if options[:show_values]
            say "#{key}=#{value}"
          else
            say key
          end
        end
      rescue ActiveSupport::EncryptedFile::MissingKeyError => error
        say error.message
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      desc "delete KEY", "Delete a credential (use dot notation for nesting, e.g. aws.access_key_id)"
      def delete(key_path_str)
        load_environment_config!

        keys = key_path_str.split(".")

        if keys.any? { |k| k.empty? }
          say_error "Invalid key path: #{key_path_str}"
          exit 1
        end

        yaml = credentials.read.presence || missing_credentials!
        parsed = YAML.load(yaml).presence || {}

        if deep_delete(parsed, keys)
          credentials.write(YAML.dump(parsed))
          say "#{key_path_str} was deleted."
        else
          say_error "Key not found: #{key_path_str}"
          exit 1
        end
      rescue ActiveSupport::EncryptedFile::MissingKeyError => error
        say error.message
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      private
        def config
          Rails.application.config.credentials
        end

        def content_path
          @content_path ||= relative_path(config.content_path)
        end

        def key_path
          @key_path ||= relative_path(config.key_path)
        end

        def credentials
          @credentials ||= Rails.application.encrypted(content_path, key_path: key_path)
        end

        def ensure_encryption_key_has_been_added
          return if credentials.key?

          require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"

          encryption_key_file_generator = Rails::Generators::EncryptionKeyFileGenerator.new
          encryption_key_file_generator.add_key_file(key_path)
        end

        def ensure_credentials_have_been_added
          require "rails/generators/rails/credentials/credentials_generator"

          Rails::Generators::CredentialsGenerator.new(
            [content_path, key_path],
            skip_secret_key_base: environment_specified? && %w[development test].include?(environment),
            quiet: true
          ).invoke_all
        end

        def change_credentials_in_system_editor
          using_system_editor do
            say "Editing #{content_path}..."
            credentials.change { |tmp_path| system_editor(tmp_path) }
            say "File encrypted and saved."
            warn_if_credentials_are_invalid
          end
        rescue ActiveSupport::EncryptedFile::MissingKeyError => error
          say error.message
        rescue ActiveSupport::MessageEncryptor::InvalidMessage
          say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
        end

        def warn_if_credentials_are_invalid
          credentials.validate!
        rescue ActiveSupport::EncryptedConfiguration::InvalidContentError => error
          say "WARNING: #{error.message}", :red
          say ""
          say "Your application will not be able to load '#{content_path}' until the error has been fixed.", :red
        end

        def missing_credentials!
          if !credentials.key?
            say_error "Missing '#{key_path}' to decrypt credentials. See `#{executable(:help)}`."
          else
            say_error "File '#{content_path}' does not exist. Use `#{executable(:edit)}` to change that."
          end
          exit 1
        end

        def relative_path(path)
          Rails.root.join(path).relative_path_from(Rails.root).to_s
        end

        def extract_environment_from_path(path)
          available_environments.find { |env| path.end_with?("#{env}.yml.enc") } || extract_custom_environment(path)
        end

        def extract_custom_environment(path)
          path =~ %r{config/credentials/(.+)\.yml\.enc} && $1
        end

        def deep_set(hash, keys, value)
          if keys.length == 1
            hash[keys.first] = value
          else
            child = hash[keys.first]
            hash[keys.first] = child = {} unless child.is_a?(Hash)
            deep_set(child, keys[1..], value)
          end
        end

        def deep_delete(hash, keys)
          if keys.length == 1
            hash.key?(keys.first) ? hash.delete(keys.first) || true : false
          else
            child = hash[keys.first]
            return false unless child.is_a?(Hash)

            result = deep_delete(child, keys[1..])
            hash.delete(keys.first) if child.empty?
            result
          end
        end

        def flatten_keys(hash, prefix = nil)
          hash.each_with_object([]) do |(key, value), result|
            full_key = prefix ? "#{prefix}.#{key}" : key.to_s
            if value.is_a?(Hash)
              result.concat(flatten_keys(value, full_key))
            else
              result << [full_key, value]
            end
          end
        end
    end
  end
end
