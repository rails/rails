require "rails/generators/base"
require "rails/secrets"

module Rails
  module Generators
    class EncryptedSecretsGenerator < Base
      def add_secrets_key_file
        unless File.exist?("config/secrets.yml.key") || File.exist?("config/secrets.yml.enc")
          key = Rails::Secrets.generate_key

          say "Adding config/secrets.yml.key to store the encryption key: #{key}"
          say ""
          say "Save this in a password manager your team can access."
          say ""
          say "If you lose the key, no one, including you, can access any encrypted secrets."

          say ""
          create_file "config/secrets.yml.key", key
          say ""
        end
      end

      def ignore_key_file
        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(key_ignore)
            say "Ignoring config/secrets.yml.key so it won't end up in Git history:"
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
        unless (defined?(@@skip_secrets_file) && @@skip_secrets_file) || File.exist?("config/secrets.yml.enc")
          say "Adding config/secrets.yml.enc to store secrets that needs to be encrypted."
          say ""
          say "For now the file contains this but it's been encrypted with the generated key:"
          say ""
          say Secrets.template, :on_green
          say ""

          Secrets.write(Secrets.template)

          say "You can edit encrypted secrets with `bin/rails secrets:edit`."
          say ""
        end

        say "Add this to your config/environments/production.rb:"
        say "config.read_encrypted_secrets = true"
      end

      def self.skip_secrets_file
        @@skip_secrets_file = true
        yield
      ensure
        @@skip_secrets_file = false
      end

      private
        def key_ignore
          [ "", "# Ignore encrypted secrets key file.", "config/secrets.yml.key", "" ].join("\n")
        end
    end
  end
end
