# frozen_string_literal: true

require "test_helper"

ActionMailbox::Ingresses::Amazon::InboundEmailsController.verifier =
  Module.new { def self.authentic?(message); true; end }

class ActionMailbox::Ingresses::Amazon::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionMailbox.ingress = :amazon }

  test "receiving an inbound email from Amazon" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_amazon_inbound_emails_url, params: { content: file_fixture("../files/welcome.eml").read }, as: :json
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal file_fixture("../files/welcome.eml").read, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end
end
