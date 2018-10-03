require_relative '../../test_helper'

class CallbackMailbox < ActionMailbox::Base
  before_processing { $before_processing = "Ran that!" }
  after_processing  { $after_processing = "Ran that too!" }
  around_processing ->(r, block) { block.call; $around_processing = "Ran that as well!" }

  def process
    $processed = mail.subject
  end
end

class BouncingCallbackMailbox < ActionMailbox::Base
  before_processing { $before_processing = [ "Pre-bounce" ] }

  before_processing do
    bounce_with BounceMailer.bounce(to: mail.from)
    $before_processing << "Bounce"
  end

  before_processing { $before_processing << "Post-bounce" }

  after_processing { $after_processing = true }

  def process
    $processed = true
  end
end

class ActionMailbox::Base::CallbacksTest < ActiveSupport::TestCase
  setup do
    $before_processing = $after_processing = $around_processing = $processed = false
    @inbound_email = create_inbound_email_from_fixture("welcome.eml")
  end

  test "all callback types" do
    CallbackMailbox.receive @inbound_email
    assert_equal "Ran that!", $before_processing
    assert_equal "Ran that too!", $after_processing
    assert_equal "Ran that as well!", $around_processing
  end

  test "bouncing in a callback terminates processing" do
    BouncingCallbackMailbox.receive @inbound_email
    assert @inbound_email.bounced?
    assert_equal [ "Pre-bounce", "Bounce" ], $before_processing
    assert_not $processed
    assert_not $after_processing
  end
end
