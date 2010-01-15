module ActionMailer
  module Railties
    class Subscriber < Rails::Subscriber
      def deliver(event)
        recipients = Array(event.payload[:to]).join(', ')
        info("Sent mail to #{recipients} (%1.fms)" % event.duration)
        debug("\n#{event.payload[:mail]}")
      end

      def receive(event)
        info("Received mail (%.1fms)" % event.duration)
        debug("\n#{event.payload[:mail]}")
      end

      def logger
        ActionMailer::Base.logger
      end
    end
  end
end