# frozen_string_literal: true

require "pathname"
require "rails/generators/base"
require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"
require "active_support/encrypted_file"

module Rails
  module Generators
    class MasterKeyGenerator < Base # :nodoc:
      def add_master_key_file
        unless master_key_path.exist?
          key = ActiveSupport::EncryptedFile.generate_key

          log "Adding #{master_key_path} to store the master encryption key: #{key}"
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
        unless master_key_path.exist?
          key_file_generator.add_key_file_silently(master_key_path, key)
        end
      end

      def ignore_master_key_file
        key_file_generator.ignore_key_file(master_key_path, ignore: key_ignore)
      end

      def ignore_master_key_file_silently
        key_file_generator.ignore_key_file_silently(master_key_path, ignore: key_ignore)
      end

      private
        def key_file_generator
          EncryptionKeyFileGenerator.new([], options)
        end

        def key_ignore
          [ "", "# Ignore master key for decrypting credentials and more.", "/#{master_key_path}", "" ].join("\n")
        end

        def master_key_path
          @master_key_path ||= if Rails.respond_to?(:application)
                                 Rails.application.credentials.key_path.relative_path_from(Rails.root)
                               else
                                 Pathname.new("config/master.key")
                               end
        end
    end
  end
end
