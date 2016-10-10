module Rails
  module Command
    class VersionCommand < Base
      def perform
        Rails::Command.invoke :application, [ "--version" ]
      end
    end
  end
end
