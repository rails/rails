module ActionMailer
  module Railties
    class Subscriber < Rails::Subscriber
      def deliver(event)
        recipients = Array(event.payload[:mailer].recipients).join(', ')
        info("Sent mail to #{recipients} (%1.fms)" % event.duration)
        debug("\n#{event.payload[:mail].encoded}")
      end

      def receive(event)
        info("Received mail (%.1fms)" % event.duration)
        debug("\n#{event.payload[:mail].encoded}")
      end

      def logger
        ActionMailer::Base.logger
      end
    end
  end
end