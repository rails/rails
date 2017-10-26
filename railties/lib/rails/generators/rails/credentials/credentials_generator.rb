# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/rails/master_key/master_key_generator"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base
      CONFIG_PATH = "config/credentials.yml.enc"
      KEY_PATH    = "config/master.key"

      def add_credentials_file
        unless File.exist?(CONFIG_PATH)
          template = credentials_template

          say "Adding #{CONFIG_PATH} to store encrypted credentials."
          say ""
          say "The following content has been encrypted with the Rails master key:"
          say ""
          say template, :on_green
          say ""

          add_credentials_file_silently(template)

          say "You can edit encrypted credentials with `bin/rails credentials:edit`."
          say ""
        end
      end

      def add_credentials_file_silently(template = nil)
        unless File.exist?(CONFIG_PATH)
          setup = { config_path: CONFIG_PATH, key_path: KEY_PATH, env_key: "RAILS_MASTER_KEY" }
          ActiveSupport::EncryptedConfiguration.new(setup).write(credentials_template)
        end
      end

      private
        def credentials_template
          "# aws:\n#  access_key_id: 123\n#  secret_access_key: 345\n\n" +
          "# Used as the base secret for all MessageVerifiers in Rails, including the one protecting cookies.\n" +
          "secret_key_base: #{SecureRandom.hex(64)}"
        end
    end
  end
end
