# frozen_string_literal: true

require "pathname"
require "rails/generators/base"
require "active_support/encrypted_file"

module Rails
  module Generators
    class EncryptionKeyFileGenerator < Base # :nodoc:
      def add_key_file(key_path)
        key_path = Pathname.new(key_path)

        unless key_path.exist?
          key = ActiveSupport::EncryptedFile.generate_key

          log "Adding #{key_path} to store the encryption key: #{key}"
          log ""
          log "Save this in a password manager your team can access."
          log ""
          log "If you lose the key, no one, including you, can access anything encrypted with it."

          log ""
          add_key_file_silently(key_path, key)
          ensure_key_files_are_ignored(key_path)
          log ""
        end
      end

      def add_key_file_silently(key_path, key = nil)
        create_file key_path, key || ActiveSupport::EncryptedFile.generate_key, perm: 0600
        ensure_key_files_are_ignored_silently(key_path)
      end

      def ensure_key_files_are_ignored(key_path, ignore: key_ignore(key_path))
        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(ignore)
            log "Ignoring #{ignore} so it won't end up in Git history:"
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

      def ensure_key_files_are_ignored_silently(key_path, ignore: key_ignore(key_path))
        if File.exist?(".gitignore")
          unless File.read(".gitignore").include?(ignore)
            append_to_file ".gitignore", ignore
          end
        end
      end

      private
        def key_ignore(key_path)
          key_path = Pathname.new(key_path) unless key_path.is_a?(Pathname)
          <<~IGNORE

            # Ignore key files for decrypting credentials and more.
            /#{key_path.dirname.join("*.key")}

          IGNORE
        end
    end
  end
end
