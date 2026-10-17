# frozen_string_literal: true

# :markup: markdown
module Rails
  module Command
    class VersionCommand < Base # :nodoc:
      desc "version", "Show the Rails version"
      def perform
        Rails::Command.invoke :application, [ "--version" ]
      end
    end
  end
end
