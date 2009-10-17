module ActionMailer
  module DeliveryMethod

    # A delivery method implementation which sends via sendmail.
    class Sendmail < Method
      self.settings = {
        :location       => '/usr/sbin/sendmail',
        :arguments      => '-i -t'
      }

      def perform_delivery(mail)
        sendmail_args = settings[:arguments]
        sendmail_args += " -f \"#{mail['return-path']}\"" if mail['return-path']
        IO.popen("#{settings[:location]} #{sendmail_args}","w+") do |sm|
          sm.print(mail.encoded.gsub(/\r/, ''))
          sm.flush
        end
      end
    end

  end
end
