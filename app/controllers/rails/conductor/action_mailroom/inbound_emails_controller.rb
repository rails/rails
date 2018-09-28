class Rails::Conductor::ActionMailroom::InboundEmailsController < Rails::Conductor::BaseController
  def index
    @inbound_emails = ActionMailroom::InboundEmail.order(created_at: :desc)
  end

  def new
  end

  def show
    @inbound_email = ActionMailroom::InboundEmail.find(params[:id])
  end

  def create
    inbound_email = create_inbound_email(new_mail)
    redirect_to main_app.rails_conductor_inbound_email_url(inbound_email)
  end

  private
    def new_mail
      Mail.new params.require(:mail).permit(:from, :to, :cc, :bcc, :subject, :body)
    end

    def create_inbound_email(mail)
      ActionMailroom::InboundEmail.create! raw_email: new_raw_email(mail), message_id: mail.message_id
    end

    def new_raw_email(mail)
      { io: StringIO.new(new_mail.to_s), filename: 'inbound.eml', content_type: 'message/rfc822', identify: false }
    end
end
