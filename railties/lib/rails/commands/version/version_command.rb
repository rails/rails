# frozen_string_literal: true

module Rails
  module Command
    class VersionCommand < Base # :nodoc:
      desc "version", "Show the Rails version"
      def perform
        Rails::Command.invoke :application, [ "--version" ]
      end
      option :foo, type: :string, default: "OK", for: :version
    end
  end
end
