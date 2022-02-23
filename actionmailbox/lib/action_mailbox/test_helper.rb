# frozen_string_literal: true

require "mail"

module ActionMailbox
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email_from_fixture(fixture_name, status: :processing)
      create_inbound_email_from_source file_fixture(fixture_name).read, status: status
    end

    # Creates an InboundEmail by specifying through options or a block.
    #
    # ==== Options
    #
    # * <tt>:status</tt> - The +status+ to set for the created InboundEmail.
    #   For possible statuses, see its documentation.
    #
    # ==== Creating a simple email
    #
    # When you only need to set basic fields like +from+, +to+, +subject+, and
    # +body+, you can pass them directly as options.
    #
    #   create_inbound_email_from_mail(from: "david@loudthinking.com", subject: "Hello!")
    #
    # ==== Creating a multi-part email
    #
    # When you need to create a more intricate email, like a multi-part email
    # that contains both a plaintext version and an HTML version, you can pass a
    # block.
    #
    #   create_inbound_email_from_mail do
    #     to "David Heinemeier Hansson <david@loudthinking.com>"
    #     from "Bilbo Baggins <bilbo@bagend.com>"
    #     subject "Come down to the Shire!"
    #
    #     text_part do
    #       body "Please join us for a party at Bag End"
    #     end
    #
    #     html_part do
    #       body "<h1>Please join us for a party at Bag End</h1>"
    #     end
    #   end
    #
    # As with +Mail.new+, you can also use a block parameter to define the parts
    # of the message:
    #
    #   create_inbound_email_from_mail do |mail|
    #     mail.to "David Heinemeier Hansson <david@loudthinking.com>"
    #     mail.from "Bilbo Baggins <bilbo@bagend.com>"
    #     mail.subject "Come down to the Shire!"
    #
    #     mail.text_part do |part|
    #       part.body "Please join us for a party at Bag End"
    #     end
    #
    #     mail.html_part do |part|
    #       part.body "<h1>Please join us for a party at Bag End</h1>"
    #     end
    #   end
    def create_inbound_email_from_mail(status: :processing, **mail_options, &block)
      mail = Mail.new(mail_options, &block)
      # Bcc header is not encoded by default
      mail[:bcc].include_in_headers = true if mail[:bcc]

      create_inbound_email_from_source mail.to_s, status: status
    end

    # Create an InboundEmail using the raw rfc822 +source+ as text.
    def create_inbound_email_from_source(source, status: :processing)
      ActionMailbox::InboundEmail.create_and_extract_message_id! source, status: status
    end


    # Create an InboundEmail from fixture using the same arguments as create_inbound_email_from_fixture
    # and immediately route it to processing.
    def receive_inbound_email_from_fixture(*args)
      create_inbound_email_from_fixture(*args).tap(&:route)
    end

    # Create an InboundEmail using the same options or block as
    # create_inbound_email_from_mail, then immediately route it for processing.
    def receive_inbound_email_from_mail(**kwargs, &block)
      create_inbound_email_from_mail(**kwargs, &block).tap(&:route)
    end

    # Create an InboundEmail using the same arguments as create_inbound_email_from_source and immediately route it
    # to processing.
    def receive_inbound_email_from_source(*args)
      create_inbound_email_from_source(*args).tap(&:route)
    end
  end
end
