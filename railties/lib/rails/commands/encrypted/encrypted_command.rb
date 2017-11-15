# frozen_string_literal: true

require "active_support"
require "pathname"

module Rails
  module Command
    class EncryptedCommand < Rails::Command::Base # :nodoc:
      class_option :key, aliases: "-k", type: :string,
        default: "config/master.key", desc: "Path to the key for encryption"

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
        end
      end

      def edit(file_path)
        file_path = Pathname.new(file_path)
        key_path  = Pathname.new(options[:key])

        require_application_and_environment!

        ensure_editor_available || (return)
        ensure_encryption_key_has_been_added(key_path)
        ensure_encrypted_file_have_been_added(file_path, key_path)

        change_encrypted_file_in_system_editor(file_path, key_path)

        say "File encrypted and saved."
      rescue Interrupt
        say "Aborted changing file: nothing saved."
      rescue ActiveSupport::EncryptedFile::MissingKeyError => error
        say error.message
      end

      def show(file_path)
        file_path = Pathname.new(file_path)
        key_path  = Pathname.new(options[:key])

        require_application_and_environment!
        encrypted_file = encrypted_file(file_path, key_path)

        say encrypted_file.content_path.exist? ? encrypted_file.read :
          "File '#{file_path}' does not exist. Use bin/rails encrypted:edit #{file_path} to change that."
      end

      private
        def ensure_editor_available
          if ENV["EDITOR"].to_s.empty?
            say "No $EDITOR to open file in. Assign one like this:"
            say ""
            say %(EDITOR="mate --wait" bin/rails encrypted:edit)
            say ""
            say "For editors that fork and exit immediately, it's important to pass a wait flag,"
            say "otherwise the credentials will be saved immediately with no chance to edit."

            false
          else
            true
          end
        end

        def ensure_encryption_key_has_been_added(key_path)
          master_key_generator.add_master_key_file(key_path)
          master_key_generator.ignore_master_key_file(key_path)
        end

        def ensure_encrypted_file_have_been_added(file_path, key_path)
          encrypted_file_generator.add_encrypted_file_silently(file_path, key_path)
        end

        def change_encrypted_file_in_system_editor(file_path, key_path)
          encrypted_file(file_path, key_path).change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end

        def encrypted_file(file_path, key_path)
          ActiveSupport::EncryptedFile.new \
            content_path: file_path,
            key_path: key_path,
            env_key: "RAILS_MASTER_KEY"
        end

        def master_key_generator
          require "rails/generators"
          require "rails/generators/rails/master_key/master_key_generator"

          Rails::Generators::MasterKeyGenerator.new
        end

        def encrypted_file_generator
          require "rails/generators"
          require "rails/generators/rails/encrypted_file/encrypted_file_generator"

          Rails::Generators::EncryptedFileGenerator.new
        end
    end
  end
end
