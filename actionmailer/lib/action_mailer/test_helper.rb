# frozen_string_literal: true

require "active_support/lazy_load_hooks"

module ActionMailer
  # Provides helper methods for testing Action Mailer, including #assert_emails
  # and #assert_no_emails. See ActiveJob::ActionMailerTestHelper for assertions
  # about enqueued emails.
  module TestHelper
    # Asserts that the number of emails sent matches the given number.
    #
    # ```
    # def test_emails
    #   assert_emails 0
    #   ContactMailer.welcome.deliver_now
    #   assert_emails 1
    #   ContactMailer.welcome.deliver_now
    #   assert_emails 2
    # end
    # ```
    #
    # If a block is passed, that block should cause the specified number of
    # emails to be sent.
    #
    # ```
    # def test_emails_again
    #   assert_emails 1 do
    #     ContactMailer.welcome.deliver_now
    #   end
    #
    #   assert_emails 2 do
    #     ContactMailer.welcome.deliver_now
    #     ContactMailer.welcome.deliver_later
    #   end
    # end
    # ```
    def assert_emails(number, &block)
      if block_given?
        diff = capture_emails(&block).length
        assert_equal number, diff, "#{number} emails expected, but #{diff} were sent"
      else
        assert_equal number, ActionMailer::Base.deliveries.size
      end
    end

    # Asserts that no emails have been sent.
    #
    # ```
    # def test_emails
    #   assert_no_emails
    #   ContactMailer.welcome.deliver_now
    #   assert_emails 1
    # end
    # ```
    #
    # If a block is passed, that block should not cause any emails to be sent.
    #
    # ```
    # def test_emails_again
    #   assert_no_emails do
    #     # No emails should be sent from this block
    #   end
    # end
    # ```
    #
    # Note: This assertion is simply a shortcut for:
    #
    # ```
    # assert_emails 0, &block
    # ```
    def assert_no_emails(&block)
      assert_emails 0, &block
    end

    # Returns any emails that are sent in the block. With the Active Job
    # integration, this also delivers any emails enqueued in the block.
    #
    # ```
    # def test_emails
    #   emails = capture_emails do
    #     ContactMailer.welcome.deliver_now
    #   end
    #   assert_equal "Hi there", emails.first.subject
    #
    #   emails = capture_emails do
    #     ContactMailer.welcome.deliver_now
    #     ContactMailer.welcome.deliver_later
    #   end
    #   assert_equal "Hi there", emails.first.subject
    # end
    # ```
    #: () ?{ () -> void } -> Array[Mail::Message]
    def capture_emails(&block)
      original_count = ActionMailer::Base.deliveries.size
      block&.call
      new_count = ActionMailer::Base.deliveries.size
      diff = new_count - original_count
      ActionMailer::Base.deliveries.last(diff)
    end
  end
end

ActiveSupport.run_load_hooks(:action_mailer_test_helper, ActionMailer::TestHelper)
