# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/rails/master_key/master_key_generator"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base # :nodoc:
      def add_credentials_file
        unless @content_path.exist?
          say "Adding #{@content_path} to store encrypted credentials."
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

      def add_credentials_file_silently(content_path, key_path, template = nil)
        unless content_path.exist?
          ActiveSupport::EncryptedFile.new(
            content_path: content_path,
            key_path: key_path,
            env_key: "RAILS_MASTER_KEY",
            raise_if_missing_key: true
          ).write(template)
        end
      end

      private
        def template
          <<~YAML
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
