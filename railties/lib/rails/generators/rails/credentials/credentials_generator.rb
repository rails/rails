# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/rails/master_key/master_key_generator"
require "active_support/core_ext/string/strip"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base # :nodoc:
      def add_credentials_file
        unless credentials.content_path.exist?
          template = credentials_template

          say "Adding #{credentials.content_path} to store encrypted credentials."
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
        unless credentials.content_path.exist?
          credentials.write(credentials_template)
        end
      end

      private
        def credentials
          ActiveSupport::EncryptedConfiguration.new(
            config_path: "config/credentials.yml.enc",
            key_path: "config/master.key",
            env_key: "RAILS_MASTER_KEY",
            raise_if_missing_key: true
          )
        end

        def credentials_template
          <<-YAML.strip_heredoc
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
