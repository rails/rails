# frozen_string_literal: true

require "rails/generators/base"
require "active_support/encrypted_file"

module Rails
  module Generators
    class EncryptedFileGenerator < Base # :nodoc:
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
