# frozen_string_literal: true

require_relative "../../base"
require "pathname"
require "active_support/encrypted_file"

module Rails
  module Generators
    class MasterKeyGenerator < Base
      MASTER_KEY_PATH = Pathname.new("config/master.key")

      def add_master_key_file
        unless MASTER_KEY_PATH.exist?
          key = ActiveSupport::EncryptedFile.generate_key

          say "Adding #{MASTER_KEY_PATH} to store the master encryption key: #{key}"
          say ""
          say "Save this in a password manager your team can access."
          say ""
          say "If you lose the key, no one, including you, can access anything encrypted with it."

          say ""
          create_file MASTER_KEY_PATH, key
          say ""

          ignore_master_key_file
        end
      end

      private
        def ignore_master_key_file
          if File.exist?(".gitignore")
            unless File.read(".gitignore").include?(key_ignore)
              say "Ignoring #{MASTER_KEY_PATH} so it won't end up in Git history:"
              say ""
              append_to_file ".gitignore", key_ignore
              say ""
            end
          else
            say "IMPORTANT: Don't commit #{MASTER_KEY_PATH}. Add this to your ignore file:"
            say key_ignore, :on_green
            say ""
          end
        end

        def key_ignore
          [ "", "# Ignore master key for decrypting credentials and more.", "/#{MASTER_KEY_PATH}", "" ].join("\n")
        end
    end
  end
end
