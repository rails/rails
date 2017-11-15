# frozen_string_literal: true

require "pathname"
require "rails/generators/base"
require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"
require "active_support/encrypted_file"

module Rails
  module Generators
    class MasterKeyGenerator < Base
      MASTER_KEY_PATH = Pathname.new("config/master.key")

      def add_master_key_file
        unless MASTER_KEY_PATH.exist?
          key = ActiveSupport::EncryptedFile.generate_key

          log "Adding #{MASTER_KEY_PATH} to store the master encryption key: #{key}"
          log ""
          log "Save this in a password manager your team can access."
          log ""
          log "If you lose the key, no one, including you, can access anything encrypted with it."

          log ""
          add_master_key_file_silently(key)
          log ""
        end
      end

      def add_master_key_file_silently(key = nil)
        key_file_generator.add_key_file_silently(MASTER_KEY_PATH, key)
      end

      def ignore_master_key_file
        key_file_generator.ignore_key_file(MASTER_KEY_PATH, ignore: key_ignore)
      end

      def ignore_master_key_file_silently
        key_file_generator.ignore_key_file_silently(MASTER_KEY_PATH, ignore: key_ignore)
      end

      private
        def key_file_generator
          EncryptionKeyFileGenerator.new([], options)
        end

        def key_ignore
          [ "", "# Ignore master key for decrypting credentials and more.", "/#{MASTER_KEY_PATH}", "" ].join("\n")
        end
    end
  end
end
