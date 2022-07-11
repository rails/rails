# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/rails/master_key/master_key_generator"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base # :nodoc:
      argument :content_path, default: "config/credentials.yml.enc"
      argument :key_path, default: "config/master.key"

      def add_credentials_file
        in_root do
          return if File.exist?(content_path)

          say "Adding #{content_path} to store encrypted credentials."
          say ""

          encrypted_file.write(content)

          say "The following content has been encrypted with the Rails master key:"
          say ""
          say content, :on_green
          say ""
          say "You can edit encrypted credentials with `bin/rails credentials:edit`."
          say ""
        end
      end

      private
        def encrypted_file
          ActiveSupport::EncryptedConfiguration.new(
            config_path: content_path,
            key_path: key_path,
            env_key: "RAILS_MASTER_KEY",
            raise_if_missing_key: true
          )
        end

        def content
          @content ||= <<~YAML
            # aws:
            #   access_key_id: 123
            #   secret_access_key: 345

            # Used as the base secret for all MessageVerifiers in Rails, including the one protecting cookies.
            secret_key_base: #{SecureRandom.hex(64)}
          YAML
        end
    end
  end
end
