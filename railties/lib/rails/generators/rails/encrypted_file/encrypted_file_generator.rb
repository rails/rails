# frozen_string_literal: true

require "rails/generators/base"
require "active_support/encrypted_file"

module Rails
  module Generators
    class EncryptedFileGenerator < Base
      def add_encrypted_file(file_path, key_path)
        unless File.exist?(file_path)
          say "Adding #{file_path} to store encrypted content."
          say ""
          say "The following content has been encrypted with the encryption key:"
          say ""
          say template, :on_green
          say ""

          add_encrypted_file_silently(file_path, key_path)

          say "You can edit encrypted file with `bin/rails encrypted:edit #{file_path}`."
          say ""
        end
      end

      def add_encrypted_file_silently(file_path, key_path, template = encrypted_file_template)
        unless File.exist?(file_path)
          setup = { content_path: file_path, key_path: key_path, env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true }
          ActiveSupport::EncryptedFile.new(setup).write(template)
        end
      end

      private
        def encrypted_file_template
          "# aws:\n#  access_key_id: 123\n#  secret_access_key: 345\n\n"
        end
    end
  end
end
