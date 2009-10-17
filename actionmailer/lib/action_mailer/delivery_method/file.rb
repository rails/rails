require 'tmpdir'

module ActionMailer
  module DeliveryMethod

    # A delivery method implementation which writes all mails to a file.
    class File < Method
      self.settings = {
        :location       => defined?(Rails) ? "#{Rails.root}/tmp/mails" : "#{Dir.tmpdir}/mails"
      }

      def perform_delivery(mail)
        FileUtils.mkdir_p settings[:location]

        (mail.to + mail.cc + mail.bcc).uniq.each do |to|
          ::File.open(::File.join(settings[:location], to), 'a') { |f| f.write(mail) }
        end
      end
    end
  end
end
