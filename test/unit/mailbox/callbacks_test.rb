require_relative '../../test_helper'

class CallbackMailbox < ActionMailbox::Base
  before_processing { $before_processing = "Ran that!" }
  after_processing  { $after_processing = "Ran that too!" }
  around_processing ->(r, block) { block.call; $around_processing = "Ran that as well!" }

  def process
    $processed = mail.subject
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
end
