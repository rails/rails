# frozen_string_literal: true

require "active_support/encrypted_file"

module Rails
  module Command
    module Helpers
      module Editor
        private

          def ensure_editor_available(command:)
            if default_editor.to_s.empty?
              say "No $EDITOR to open file in. Assign one like this:"
              say ""
              say %(EDITOR="mate --wait" #{command})
              say ""
              say "You can also assign a default editor in an environment file like development.rb:"
              say "config.credentials.default_editor = 'vim'"
              say "For editors that fork and exit immediately, it's important to pass a wait flag,"
              say "otherwise the credentials will be saved immediately with no chance to edit."

              false
            else
              true
            end
          end

          def default_editor
            ENV["EDITOR"] || Rails.application.config.credentials&.default_editor
          end

          def catch_editing_exceptions
            yield
          rescue Interrupt
            say "Aborted changing file: nothing saved."
          rescue ActiveSupport::EncryptedFile::MissingKeyError => error
            say error.message
          end
      end
    end
  end
end
