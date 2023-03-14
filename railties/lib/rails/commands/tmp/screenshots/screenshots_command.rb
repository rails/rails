# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    module Tmp
      class ScreenshotsCommand < Base # :nodoc:
        include Rails::Command::Tmp::Helpers

        # desc :clear, "Clear all files in tmp/screenshots"
        def clear
          clear_tmp_dir "screenshots"
        end
      end
    end
  end
end

