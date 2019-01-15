# frozen_string_literal: true

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
        Mail.new(params.require(:mail).permit(:from, :to, :cc, :bcc, :in_reply_to, :subject, :body).to_h).tap do |mail|
          params[:mail][:attachments].to_a.each do |attachment|
            mail.attachments[attachment.original_filename] = { filename: attachment.path, content_type: attachment.content_type }
          end
        end
      end

      def create_inbound_email(mail)
        ActionMailbox::InboundEmail.create! raw_email: \
          { io: StringIO.new(mail.to_s), filename: "inbound.eml", content_type: "message/rfc822" }
      end
  end
end
