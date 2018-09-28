require_relative '../test_helper'

module ActionMailroom
  class InboundEmailTest < ActiveSupport::TestCase
    test "mail provides the parsed source" do
      assert_equal "Discussion: Let's debate these attachments", create_inbound_email_from_fixture("welcome.eml").mail.subject
    end

    test "source returns the contents of the raw email" do
      assert_equal file_fixture("welcome.eml").read, create_inbound_email_from_fixture("welcome.eml").source
    end
  end
end
