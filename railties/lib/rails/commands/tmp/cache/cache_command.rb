# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    module Tmp
      class CacheCommand < Base # :nodoc:
        include Rails::Command::Tmp::Helpers

        # desc :clear, "Clear all files and directories in tmp/cache"
        def clear
          clear_tmp_dir "cache"
        end
      end
    end
  end
end
