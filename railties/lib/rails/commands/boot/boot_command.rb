# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  module Command
    class BootCommand < Base # :nodoc:
      include EnvironmentArgument

      desc "boot", "Boot the application and exit"
      def perform(*)
        puts "Booting the application."
        boot_application!
        puts "All is good!"
      end
    end
  end
end
