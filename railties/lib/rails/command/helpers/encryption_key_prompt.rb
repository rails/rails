# frozen_string_literal: true

require "active_support/encrypted_configuration"

module Rails
  module Command
    module Helpers
      module EncryptionKeyPrompt
        ENCRYPTION_KEY_ATTEMPTS = 3

        private
          def can_prompt_for_encryption_key?(encrypted_file)
            encrypted_file.content_path.exist? && $stdin.tty?
          end

          def prompt_for_encrypted_configuration(content_path, key_path)
            say "Missing '#{key_path}' to decrypt '#{content_path}'."

            ENCRYPTION_KEY_ATTEMPTS.times do |attempt|
              say "Sorry, try again." if attempt > 0
              encrypted_configuration = encrypted_configuration_with_key(content_path, ask_without_echo("Enter the encryption key: "))
              return encrypted_configuration if encrypted_configuration
            end

            say_error "#{ENCRYPTION_KEY_ATTEMPTS} incorrect encryption key attempts."
            exit 1
          rescue Interrupt
            say "Aborted."
            exit 1
          end

          def ask_without_echo(prompt)
            require "io/console"

            $stdin.noecho do
              say prompt, nil, false
              $stdin.gets.to_s.strip
            end
          ensure
            say ""
          end

          def encrypted_configuration_with_key(content_path, key)
            return if key.empty?

            encrypted_configuration = Rails.application.encrypted(content_path, key: key)
            encrypted_configuration.read
            encrypted_configuration
          rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
            nil
          end
      end
    end
  end
end
