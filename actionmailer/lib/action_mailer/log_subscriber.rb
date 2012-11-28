module ActionMailer
  class LogSubscriber < ActiveSupport::LogSubscriber
    def deliver(event)
      return unless logger.info?
      recipients = Array(event.payload[:to]).join(', ')
      info("\nSent mail to #{recipients} (#{event.duration.round(1)}ms)")
      debug(event.payload[:mail])
    end

    def receive(event)
      return unless logger.info?
      info("\nReceived mail (#{event.duration.round(1)}ms)")
      debug(event.payload[:mail])
    end

    def logger
      ActionMailer::Base.logger
    end
  end
end

ActionMailer::LogSubscriber.attach_to :action_mailer
