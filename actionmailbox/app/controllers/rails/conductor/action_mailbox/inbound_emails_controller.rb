# frozen_string_literal: true

# :enddoc:

module Rails
  class Conductor::ActionMailbox::InboundEmailsController < Rails::Conductor::BaseController
    def index
      @inbound_emails = ActionMailbox::InboundEmail.order(created_at: :desc)
    end

    def new
    end

    def show
      @inbound_email = ActionMailbox::InboundEmail.find(params[:id])
    end

    def create
      inbound_email = create_inbound_email(new_mail)
      redirect_to main_app.rails_conductor_inbound_email_url(inbound_email)
    end

    private
      def new_mail
        Mail.new(mail_params.except(:attachments).to_h).tap do |mail|
          mail[:bcc]&.include_in_headers = true
          mail_params[:attachments]&.select(&:present?)&.each do |attachment|
            mail.add_file(filename: attachment.original_filename, content: attachment.read)
          end
        end
      end

      def mail_params
        params.expect(mail: [:from, :to, :cc, :bcc, :x_original_to, :in_reply_to, :subject, :body, attachments: []])
      end

      def create_inbound_email(mail)
        ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
      end
  end
end
