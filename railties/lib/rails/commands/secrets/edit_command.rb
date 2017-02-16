require "active_support"
require "active_support/core_ext/string/strip"

require "rails/generators/rails/app/app_generator"

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

            Sekrets.tmpdir do
              IO.binwrite(decrypted_path, contents)
              mtime = File.mtime(decrypted_path)

              system("\$EDITOR #{decrypted_path}")

              until File.mtime(decrypted_path) != mtime
                sleep 0.250
                Sekrets.write(encrypted_path.to_s, IO.binread(decrypted_path))
              end
            end
          end

          def decrypted_path
            encrypted_path.basename
          end

          def encrypted_path
            Rails.root.join("config", "secrets.yml.enc")
          end
      end
    end
  end
end
