# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    module Tmp
      class PidsCommand < Base # :nodoc:
        include Rails::Command::Tmp::Helpers

        # desc :clear, "Clear all files in tmp/pids"
        def clear
          clear_tmp_dir "pids"
        end
      end
    end
  end
end
