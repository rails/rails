# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  module Command
    class BootCommand < Base # :nodoc:
      include EnvironmentArgument

      desc "boot", "Boot the application and exit"
      def perform(*) = boot_application!
    end
  end
end
