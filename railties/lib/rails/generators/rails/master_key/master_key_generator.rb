# frozen_string_literal: true

require "rails/generators/base"
require "pathname"
require "active_support/encrypted_file"

module Rails
  module Generators
    class MasterKeyGenerator < Base
      MASTER_KEY_PATH = Pathname.new("config/master.key")

      def add_master_key_file(key_path = MASTER_KEY_PATH)
        unless key_path.exist?
          key = ActiveSupport::EncryptedFile.generate_key

          log "Adding #{key_path} to store the master encryption key: #{key}"
          log ""
          log "Save this in a password manager your team can access."
          log ""
          log "If you lose the key, no one, including you, can access anything encrypted with it."

          log ""
          add_master_key_file_silently(key, key_path)
          log ""
        end
      end

      def add_master_key_file_silently(key = nil, key_path = MASTER_KEY_PATH)
        create_file key_path, key || ActiveSupport::EncryptedFile.generate_key
      end

      def ignore_master_key_file(key_path = MASTER_KEY_PATH)
        ignore = key_ignore(key_path)

        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(ignore)
            log "Ignoring #{key_path} so it won't end up in Git history:"
            log ""
            append_to_file ".gitignore", ignore
            log ""
          end
        else
          log "IMPORTANT: Don't commit #{key_path}. Add this to your ignore file:"
          log ignore, :on_green
          log ""
        end
      end

      private
        def key_ignore(key_path)
          [ "", "# Ignore master key for decrypting credentials and more.", "/#{key_path}", "" ].join("\n")
        end
    end
  end
end
