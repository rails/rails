# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/rails/master_key/master_key_generator"
require "active_support/encrypted_configuration"

module Rails
  module Generators
    class CredentialsGenerator < Base # :nodoc:
      argument :content_path, default: "config/credentials.yml.enc"
      argument :key_path, default: "config/master.key"
      class_option :skip_secret_key_base, type: :boolean

      def add_credentials_file
        in_root do
          return if File.exist?(content_path)

          say "Adding #{content_path} to store encrypted credentials."
          say ""

          content = render_template_to_encrypted_file

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

        def secret_key_base
          @secret_key_base ||= SecureRandom.hex(64)
        end

        def render_template_to_encrypted_file
          empty_directory File.dirname(content_path)

          content = nil

          encrypted_file.change do |tmp_path|
            template("credentials.yml", tmp_path, force: true, verbose: false) do |rendered|
              content = rendered
            end
          end

          content
        end
    end
  end
end
