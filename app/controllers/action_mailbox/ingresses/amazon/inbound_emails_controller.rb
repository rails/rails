class ActionMailbox::Ingresses::Amazon::InboundEmailsController < ActionMailbox::BaseController
  before_action :authenticate

  cattr_accessor :verifier

  def self.prepare
    self.verifier ||= begin
      require "aws-sdk-sns/message_verifier"
      Aws::SNS::MessageVerifier.new
    end
  end

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require(:content)
  end

  private
    def authenticate
      head :unauthorized unless verifier.authentic?(request.body)
    end
end
