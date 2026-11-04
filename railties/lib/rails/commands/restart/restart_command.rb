# frozen_string_literal: true

module Rails
  module Command
    class RestartCommand < Base # :nodoc:
      desc "restart", "Restart app by touching tmp/restart.txt"
      def perform
        require "fileutils"
        FileUtils.mkdir_p Rails::Command.application_root.join("tmp")
        FileUtils.touch   Rails::Command.application_root.join("tmp/restart.txt")
      end
    end
  end
end
