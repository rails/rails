# frozen_string_literal: true

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

      def edit
        require_application_and_environment!

        ensure_editor_available || (return)
        ensure_master_key_has_been_added
        ensure_credentials_have_been_added

        change_credentials_in_system_editor

        say "New credentials encrypted and saved."
      rescue Interrupt
        say "Aborted changing credentials: nothing saved."
      rescue ActiveSupport::EncryptedFile::MissingKeyError => error
        say error.message
      end

      def show
        require_application_and_environment!
        say Rails.application.credentials.read.presence ||
          "No credentials have been added yet. Use bin/rails credentials:edit to change that."
      end

      private
        def ensure_editor_available
          if ENV["EDITOR"].to_s.empty?
            say "No $EDITOR to open credentials in. Assign one like this:"
            say ""
            say %(EDITOR="mate --wait" bin/rails credentials:edit)
            say ""
            say "For editors that fork and exit immediately, it's important to pass a wait flag,"
            say "otherwise the credentials will be saved immediately with no chance to edit."

            false
          else
            true
          end
        end

        def ensure_master_key_has_been_added
          master_key_generator.add_master_key_file
          master_key_generator.ignore_master_key_file
        end

        def ensure_credentials_have_been_added
          credentials_generator.add_credentials_file_silently
        end

        def change_credentials_in_system_editor
          Rails.application.credentials.change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end


        def master_key_generator
          require "rails/generators"
          require "rails/generators/rails/master_key/master_key_generator"

          Rails::Generators::MasterKeyGenerator.new
        end

        def credentials_generator
          require "rails/generators"
          require "rails/generators/rails/credentials/credentials_generator"

          Rails::Generators::CredentialsGenerator.new
        end
    end
  end
end
