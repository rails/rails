require "active_support"

module Rails
  module Command
    class CredentialsCommand < Rails::Command::Base # :nodoc:
      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def setup
        generator.start
      end

      def edit
        if ENV["EDITOR"].to_s.empty?
          say "No $EDITOR to open decrypted secrets in. Assign one like this:"
          say ""
          say %(EDITOR="mate --wait" bin/rails credentials:edit)
          say ""
          say "For editors that fork and exit immediately, it's important to pass a wait flag,"
          say "otherwise the secrets will be saved immediately with no chance to edit."

          return
        end

        require_application_and_environment!

        Rails.application.credentials.change do |tmp_path|
          system("#{ENV["EDITOR"]} #{tmp_path}")
        end

        say "New credentials encrypted and saved."
      rescue Interrupt
        say "Aborted changing credentials: nothing saved."
      rescue ActiveSupport::EncryptedConfiguration::MissingKeyError => error
        say error.message
      end

      def show
        say Rails.application.credentials.read
      end

      private
        def generator
          require_relative "../../generators"
          require_relative "../../generators/rails/credentials/credentials_generator"

          Rails::Generators::CredentialsGenerator
        end
    end
  end
end
