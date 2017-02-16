require "active_support"
require "active_support/core_ext/string/strip"
require "rails/generators/rails/app/app_generator"

require "rails/engine"
require "sekrets"

module Rails
  module Command
    module Secrets
      class EditCommand < Rails::Command::Base # :nodoc:
        def help
          super
          puts self.class.desc
        end

        def perform
          require_application_and_environment!
          override_defaults

          setup_encrypted_secrets_files

          open_decrypted_file_and_await_write
        end

        private
          def override_defaults
            Sekrets.env    = "RAILS_MASTER_KEY"
            Sekrets.root   = Rails.root
            Sekrets.project_key = Rails.root.join("config", "secrets.yml.key")
          end

          def setup_encrypted_secrets_files
            Rails::Generators::AppGenerator.new([ Rails.root ]).setup_encrypted_secrets
          end

          def open_decrypted_file_and_await_write
            Sekrets.tmpdir do
              IO.binwrite(decrypted_path, Sekrets.read(encrypted_path) || prefill_contents)
              mtime, start_time = File.mtime(decrypted_path), Time.now

              puts "Waiting for secrets file to be saved. Abort with CTRL-C."
              system("\$EDITOR #{decrypted_path}")

              editor_exits_after_open = $?.success? && (Time.now - start_time) < 1
              if editor_exits_after_open
                sleep 0.250 until File.mtime(decrypted_path) != mtime
              end

              Sekrets.write(encrypted_path.to_s, IO.binread(decrypted_path))
              puts "New secrets encrypted and saved."
            end
          rescue Interrupt
            puts "Aborted changing encrypted secrets: nothing saved."
          end

          def decrypted_path
            encrypted_path.basename
          end

          def encrypted_path
            Rails.root.join("config", "secrets.yml.enc")
          end

          def prefill_contents
            "production:\n  secret_key_base: #{SecureRandom.hex(64)}\n\n"
          end
      end
    end
  end
end
