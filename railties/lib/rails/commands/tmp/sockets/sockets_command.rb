# frozen_string_literal: true

require "rails/commands/tmp/helpers"

module Rails
  module Command
    module Tmp
      class SocketsCommand < Base # :nodoc:
        include Rails::Command::Tmp::Helpers

        # desc :clear, "Clear all files in tmp/sockets"
        def clear
          clear_tmp_dir "sockets"
        end
      end
    end
  end
end
