# frozen_string_literal: true

module Rails
  module Command
    class MiddlewareCommand < Base # :nodoc:
      desc "middleware", "Print out your Rack middleware stack"
      def perform
        boot_application!

        Rails.configuration.middleware.each do |middleware|
          say "use #{middleware.inspect}"
        end
        say "run #{Rails.application.class.name}.routes"
      end
    end
  end
end
