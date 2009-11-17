module ActionMailer
  module DeliveryMethod
    # A delivery method implementation which sends via smtp.
    class Smtp < Method

      self.settings = {
        :address              => "localhost",
        :port                 => 25,
        :domain               => 'localhost.localdomain',
        :user_name            => nil,
        :password             => nil,
        :authentication       => nil,
        :enable_starttls_auto => true,
      }

      def perform_delivery(mail)
        destinations = mail.destinations
        mail.ready_to_send
        sender = (mail['return-path'] && mail['return-path'].spec) || mail['from']

        smtp = Net::SMTP.new(settings[:address], settings[:port])
        smtp.enable_starttls_auto if settings[:enable_starttls_auto] && smtp.respond_to?(:enable_starttls_auto)
        smtp.start(settings[:domain], settings[:user_name], settings[:password],
                   settings[:authentication]) do |smtp|
          smtp.sendmail(mail.encoded, sender, destinations)
        end
      end
    end

  end
end
