require_relative "../../base"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base
      CONFIG_PATH = "config/credentials.yml.enc"
      KEY_PATH    = "config/credentials.yml.key"

      def add_secrets_key_file
        unless File.exist?(CONFIG_PATH) || File.exist?(KEY_PATH)
          key = ActiveSupport::EncryptedConfiguration.generate_key

          say "Adding #{KEY_PATH} to store the encryption key: #{key}"
          say ""
          say "Save this in a password manager your team can access."
          say ""
          say "If you lose the key, no one, including you, can access any encrypted credentials."

          say ""
          create_file KEY_PATH, key
          say ""
        end
      end

      def ignore_key_file
        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(key_ignore)
            say "Ignoring config/credentials.yml.key so it won't end up in Git history:"
            say ""
            append_to_file ".gitignore", key_ignore
            say ""
          end
        else
          say "IMPORTANT: Don't commit config/secrets.yml.key. Add this to your ignore file:"
          say key_ignore, :on_green
          say ""
        end
      end

      def add_encrypted_secrets_file
        template = "# amazon:\n#  access_key_id: 123\n#  secret_access_key: 345"

        unless File.exist?(CONFIG_PATH)
          say "Adding #{CONFIG_PATH} to store secrets that needs to be encrypted."
          say ""
          say "For now the file contains this but it's been encrypted with the generated key:"
          say ""
          say template, :on_green
          say ""

          setup = { config_path: CONFIG_PATH, key_path: KEY_PATH, env_key: 'RAILS_CREDENTIALS_KEY' }
          ActiveSupport::EncryptedConfiguration.new(setup).write(template)

          say "You can edit encrypted secrets with `bin/rails credentials:edit`."
          say ""
        end

        say "Add this to your config/environments/production.rb:"
        say "config.read_credentials = true"
      end


      private
        def key_ignore
          [ "", "# Ignore encrypted credentials key file.", KEY_PATH, "" ].join("\n")
        end
    end
  end
end
