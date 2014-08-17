require 'active_job'

module ActionMailer
  class DeliveryJob < ActiveJob::Base
    queue_as :mailers

    def perform(mailer, mail_method, delivery_method, *args)
      mailer.constantize.public_send(mail_method, *args).send(delivery_method)
    end
  end
end
