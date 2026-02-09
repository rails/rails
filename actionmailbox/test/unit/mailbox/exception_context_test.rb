# frozen_string_literal: true

require_relative "../../test_helper"

class RaisingMailbox < ActionMailbox::Base
  def process
    raise ArgumentError, "boom"
  end
end

class ActionMailbox::Base::ExceptionContextTest < ActiveSupport::TestCase
  test "raised errors include inbound email reference" do
    inbound_email = create_inbound_email_from_fixture("welcome.eml")
    reference = inbound_email.to_gid_param || inbound_email.id.to_s

    error = assert_raises(ArgumentError) do
      RaisingMailbox.receive(inbound_email)
    end

    assert_includes error.message, reference
  end
end
