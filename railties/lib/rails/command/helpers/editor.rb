# frozen_string_literal: true

require "shellwords"
require "active_support/encrypted_file"

module Rails
  module Command
    module Helpers
      module Editor
        private
          EDITOR_DURATION_THRESHOLD = 1.second

          def editor
            ENV["VISUAL"].to_s.empty? ? ENV["EDITOR"] : ENV["VISUAL"]
          end

          def display_hint_if_system_editor_not_specified
            if editor.to_s.empty?
              say "No $VISUAL or $EDITOR to open file in. Assign one like this:"
              say ""
              say %(VISUAL="code --wait" #{executable(current_subcommand)})
              say ""
              say "For editors that fork and exit immediately, it's important to pass a wait flag;"
              say "otherwise, the file will be saved immediately with no chance to edit."

              true
            end
          end

          def system_editor(file_path)
            edit_start_time = Time.now.to_i
            system(*Shellwords.split(editor), file_path.to_s)
            edit_end_time = Time.now.to_i
            if edit_end_time - edit_start_time <= EDITOR_DURATION_THRESHOLD
              say "It seems that the editor exited immediately. If this was unintentional, you"
              say "may need to pass a wait flag to your editor command, so you have a chance"
              say "to edit the file:"
              say %(VISUAL="mate --wait" #{executable(current_subcommand)})
            end
          end

          def using_system_editor
            display_hint_if_system_editor_not_specified || yield
          rescue Interrupt
            say "Aborted changing file: nothing saved."
          end
      end
    end
  end
end
