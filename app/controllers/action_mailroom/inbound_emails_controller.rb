# TODO: Add access protection using basic auth with verified tokens. Maybe coming from credentials by default?
# TODO: Spam/malware catching?
# TODO: Specific bounces for SMTP good citizenship: 200/404/400
class ActionMailroom::InboundEmailsController < ActionController::Base
  layout "action_mailroom"

  skip_forgery_protection
  before_action :ensure_development_env, except: :create
  before_action :require_rfc822_message, only: :create

  def index
    @inbound_emails = ActionMailroom::InboundEmail.order(created_at: :desc)
  end

  def new
  end

  def show
    @inbound_email = ActionMailroom::InboundEmail.find(params[:id])
  end

  def create
    ActionMailroom::InboundEmail.create_from_raw_email!(params[:message])

    respond_to do |format|
      format.html { redirect_to main_app.rails_new_inbound_email_url }
      format.any  { head :created }
    end
  end

  private
    # TODO: Should probably separate the admin interface and do more to ensure that it isn't exposed to the web
    def ensure_development_env
      head :forbidden unless Rails.env.development?
    end

    def require_rfc822_message
      head :unsupported_media_type unless params.require(:message).content_type == 'message/rfc822'
    end
end
