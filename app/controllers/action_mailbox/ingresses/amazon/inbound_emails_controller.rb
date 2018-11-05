class ActionMailbox::Ingresses::Amazon::InboundEmailsController < ActionMailbox::BaseController
  before_action :authenticate

  # TODO: Lazy-load the AWS SDK
  require "aws-sdk-sns/message_verifier"
  cattr_accessor :verifier, default: Aws::SNS::MessageVerifier.new

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require(:content)
  end

  private
    def authenticate
      head :unauthorized unless verifier.authentic?(request.body)
    end
end
