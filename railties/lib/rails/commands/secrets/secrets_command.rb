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
          watch tmp_path do
            puts "Waiting for secrets file to be saved. Abort with Ctrl-C."
            system("\$EDITOR #{tmp_path}")
          end
        end

        puts "New secrets encrypted and saved."
      rescue Interrupt
        puts "Aborted changing encrypted secrets: nothing saved."
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      end

      private
        def watch(tmp_path)
          mtime, start_time = File.mtime(tmp_path), Time.now

          yield

          editor_exits_after_open = $?.success? && (Time.now - start_time) < 1
          if editor_exits_after_open
            sleep 0.250 until File.mtime(tmp_path) != mtime
          end
        end
    end
  end
end
