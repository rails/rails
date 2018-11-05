class ActionMailbox::Ingresses::Postfix::InboundEmailsController < ActionMailbox::BaseController
  before_action :authenticate_by_password, :require_valid_rfc822_message

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! request.body.read
  end

  private
    def require_valid_rfc822_message
      unless request.content_type == "message/rfc822"
        head :unsupported_media_type
      end
    end
end
