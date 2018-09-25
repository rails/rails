require_relative '../test_helper'

module ActionMailroom
  class InboundEmailTest < ActiveSupport::TestCase
    test "message id is extracted from raw email" do
      inbound_email = create_inbound_email_from_fixture("welcome.eml")
      assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
    end
  end
end
