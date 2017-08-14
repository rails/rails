require_relative "../../base"
require_relative "../../../secrets"

module Rails
  module Generators
    class EncryptedSecretsGenerator < Base
      argument :path

      def add_secrets_key_file
        unless File.exist?(secrets.key_path) || File.exist?(secrets.path)
          key = Secrets.generate_key

          say "Adding #{secrets.key_path} to store the encryption key: #{key}"
          say ""
          say "Save this in a password manager your team can access."
          say ""
          say "If you lose the key, no one, including you, can access any encrypted secrets."

          say ""
          create_file secrets.key_path, key
          say ""
        end
      end

      def ignore_key_file
        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(key_ignore)
            say "Ignoring #{secrets.key_path} so it won't end up in Git history:"
            say ""
            append_to_file ".gitignore", key_ignore
            say ""
          end
        else
          say "IMPORTANT: Don't commit #{secrets.key_path}. Add this to your ignore file:"
          say key_ignore, :on_green
          say ""
        end
      end

      def add_encrypted_secrets_file
        unless (defined?(@@skip_secrets_file) && @@skip_secrets_file) || File.exist?(secrets.path)
          say "Adding #{secrets.path} to store secrets that needs to be encrypted."
          say ""
          say "For now the file contains this but it's been encrypted with the generated key:"
          say ""
          say Secrets.template, :on_green
          say ""

          secrets.write(Secrets.template)

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
        def secrets
          @secrets ||= Secrets.new(path)
        end

        def key_ignore
          [ "", "# Ignore encrypted secrets key file.", secrets.key_path, "" ].join("\n")
        end
    end
  end
end
