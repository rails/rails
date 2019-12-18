# frozen_string_literal: true

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
        deprecate_in_favor_of_credentials_and_exit
      end

      def edit
        if ENV["EDITOR"].to_s.empty?
          say "No $EDITOR to open decrypted secrets in. Assign one like this:"
          say ""
          say %(EDITOR="mate --wait" rails secrets:edit)
          say ""
          say "For editors that fork and exit immediately, it's important to pass a wait flag,"
          say "otherwise the secrets will be saved immediately with no chance to edit."

          return
        end

        require_application_and_environment!

        Rails::Secrets.read_for_editing do |tmp_path|
          system("#{ENV["EDITOR"]} #{tmp_path}")
        end

        say "New secrets encrypted and saved."
      rescue Interrupt
        say "Aborted changing encrypted secrets: nothing saved."
      rescue Rails::Secrets::MissingKeyError => error
        say error.message
      rescue Errno::ENOENT => error
        if /secrets\.yml\.enc/.match?(error.message)
          deprecate_in_favor_of_credentials_and_exit
        else
          raise
        end
      end

      def show
        say Rails::Secrets.read
      end

      private
        def deprecate_in_favor_of_credentials_and_exit
          say "Encrypted secrets is deprecated in favor of credentials. Run:"
          say "rails credentials:help"

          exit 1
        end
    end
  end
end
