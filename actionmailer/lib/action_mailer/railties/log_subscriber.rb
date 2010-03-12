module ActionMailer
  module Railties
    class LogSubscriber < Rails::LogSubscriber
      def deliver(event)
        recipients = Array(event.payload[:to]).join(', ')
        info("\nSent mail to #{recipients} (%1.fms)" % event.duration)
        debug(event.payload[:mail])
      end

      def receive(event)
        info("\nReceived mail (%.1fms)" % event.duration)
        debug(event.payload[:mail])
      end

      def logger
        ActionMailer::Base.logger
      end
    end
  end
end