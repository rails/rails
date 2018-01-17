# frozen_string_literal: true

require "pathname"
require "rails/generators/base"
require "active_support/encrypted_file"

module Rails
  module Generators
    class EncryptionKeyFileGenerator < Base
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
          log ""
        end
      end

      def add_key_file_silently(key_path, key = nil)
        create_file key_path, key || ActiveSupport::EncryptedFile.generate_key
      end

      def ignore_key_file(key_path, ignore: key_ignore(key_path))
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

      def ignore_key_file_silently(key_path, ignore: key_ignore(key_path))
        append_to_file ".gitignore", ignore if File.exist?(".gitignore")
      end

      private
        def key_ignore(key_path)
          [ "", "/#{key_path}", "" ].join("\n")
        end
    end
  end
end
