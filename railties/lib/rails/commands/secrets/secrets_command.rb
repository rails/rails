require "active_support"
require "rails/secrets"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def setup
        require "rails/generators"
        require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"

        Rails::Generators::EncryptedSecretsGenerator.start
      end

      def edit
        if ENV["EDITOR"].to_s.empty?
          say "No $EDITOR to open decrypted secrets in. Assign one like this:"
          say ""
          say %(EDITOR="mate --wait" bin/rails secrets:edit)
          say ""
          say "For editors that fork and exit immediately, it's important to pass a wait flag,"
          say "otherwise the secrets will be saved immediately with no chance to edit."

          return
        end

        require_application_and_environment!

        Rails::Secrets.read_for_editing do |tmp_path|
          say "Waiting for secrets file to be saved. Abort with Ctrl-C."
          system("\$EDITOR #{tmp_path}")
        end

        say "New secrets encrypted and saved."
      rescue Interrupt
        say "Aborted changing encrypted secrets: nothing saved."
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      end
    end
  end
end
