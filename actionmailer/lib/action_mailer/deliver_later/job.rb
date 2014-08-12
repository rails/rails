module ActionMailer
  module DeliverLater
    class Job < ActiveJob::Base
      queue_as :mailers

      def perform(mailer, mail_method, delivery_method, *args)
        mailer.constantize.send(mail_method, *args).send(delivery_method)
      end
    end
  end
end
