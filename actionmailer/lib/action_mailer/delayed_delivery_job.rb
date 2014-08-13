require 'active_job'

module ActionMailer
  class DelayedDeliveryJob < ActiveJob::Base
    queue_as :mailers

    def perform(mailer, mail_method, delivery_method, *args)
      mailer.constantize.send(mail_method, *args).send(delivery_method)
    end
  end
end
