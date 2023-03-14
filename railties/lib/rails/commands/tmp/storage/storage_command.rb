# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    module Tmp
      class StorageCommand < Base # :nodoc:
        include Rails::Command::Tmp::Helpers

        # desc :clear, "Clear all files and directories in tmp/storage"
        def clear
          clear_tmp_dir "storage"
        end
      end
    end
  end
end

