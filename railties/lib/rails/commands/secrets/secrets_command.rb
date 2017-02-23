require "active_support"
require "rails/secrets"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      def help
        say "Usage:\n  #{self.class.banner}"
        say ""
        say self.class.desc
      end

      def setup
        require "rails/generators"
        require "rails/generators/rails/encrypted_secrets/encrypted_secrets_generator"

        Rails::Generators::EncryptedSecretsGenerator.start
      end

      def edit
        require_application_and_environment!

        Rails::Secrets.read_for_editing do |tmp_path|
          puts "Waiting for secrets file to be saved. Abort with Ctrl-C."
          system("\$EDITOR #{tmp_path}")
        end

        puts "New secrets encrypted and saved."
      rescue Interrupt
        puts "Aborted changing encrypted secrets: nothing saved."
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      end
    end
  end
end
