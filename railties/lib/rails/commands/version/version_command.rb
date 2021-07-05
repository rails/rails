# frozen_string_literal: true

module Rails
  module Command
    class VersionCommand < Base # :nodoc:
      def perform
        require "rails/version"
        puts "Rails #{Rails::VERSION::STRING}"
      end
    end
  end
end
