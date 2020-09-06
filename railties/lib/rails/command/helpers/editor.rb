# frozen_string_literal: true

require 'active_support/encrypted_file'

module Rails
  module Command
    module Helpers
      module Editor
        private
          def ensure_editor_available(command:)
            if ENV['EDITOR'].to_s.empty?
              say 'No $EDITOR to open file in. Assign one like this:'
              say ''
              say %(EDITOR="mate --wait" #{command})
              say ''
              say "For editors that fork and exit immediately, it's important to pass a wait flag,"
              say 'otherwise the credentials will be saved immediately with no chance to edit.'

              false
            else
              true
            end
          end

          def catch_editing_exceptions
            yield
          rescue Interrupt
            say 'Aborted changing file: nothing saved.'
          rescue ActiveSupport::EncryptedFile::MissingKeyError => error
            say error.message
          end
      end
    end
  end
end
