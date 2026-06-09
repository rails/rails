# frozen_string_literal: true

require "abstract_unit"
require "mailers/callback_mailer"
require "active_support/testing/stream"

class ActionMailerCallbacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::Stream

  setup do
    @previous_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    CallbackMailer.raise_on_missing_callback_actions = false
    CallbackMailer.rescue_from_error = nil
    CallbackMailer.after_deliver_instance = nil
    CallbackMailer.around_deliver_instance = nil
    CallbackMailer.abort_before_deliver = nil
    CallbackMailer.abort_before_action = nil
    CallbackMailer.around_handles_error = nil
    CallbackMailer.deliver_callback_log = []
  end

  teardown do
    ActionMailer::Base.deliveries.clear
    ActionMailer::Base.delivery_method = @previous_delivery_method
    CallbackMailer.raise_on_missing_callback_actions = false
    CallbackMailer.rescue_from_error = nil
    CallbackMailer.after_deliver_instance = nil
    CallbackMailer.around_deliver_instance = nil
    CallbackMailer.abort_before_deliver = nil
    CallbackMailer.abort_before_action = nil
    CallbackMailer.around_handles_error = nil
    CallbackMailer.deliver_callback_log = []
  end

  test "deliver_now should call after_deliver callback and can access sent message" do
    mail_delivery = CallbackMailer.test_message
    mail_delivery.deliver_now

    assert_kind_of CallbackMailer, CallbackMailer.after_deliver_instance
    assert_not_empty CallbackMailer.after_deliver_instance.message.message_id
    assert_equal mail_delivery.message_id, CallbackMailer.after_deliver_instance.message.message_id
    assert_equal "test-receiver@test.com", CallbackMailer.after_deliver_instance.message.to.first
  end

  test "deliver_now! should call after_deliver callback" do
    CallbackMailer.test_message.deliver_now!

    assert_kind_of CallbackMailer, CallbackMailer.after_deliver_instance
  end

  test "before_action can abort message construction, resulting in NullMail" do
    CallbackMailer.abort_before_action = true

    message = CallbackMailer.test_message.message

    assert_instance_of ActionMailer::Base::NullMail, message
  end

  test "before_deliver can abort the delivery and not run after_deliver callbacks" do
    CallbackMailer.abort_before_deliver = true

    mail_delivery = CallbackMailer.test_message
    mail_delivery.deliver_now

    assert_nil mail_delivery.message_id
    assert_nil CallbackMailer.after_deliver_instance
  end

  test "deliver_later should call after_deliver callback and can access sent message" do
    perform_enqueued_jobs do
      silence_stream($stdout) do
        CallbackMailer.test_message.deliver_later
      end
    end
    assert_kind_of CallbackMailer, CallbackMailer.after_deliver_instance
    assert_not_empty CallbackMailer.after_deliver_instance.message.message_id
  end

  test "deliver callbacks support only conditions" do
    CallbackMailer.test_message.deliver_now

    assert_includes CallbackMailer.deliver_callback_log, :before_only
    assert_includes CallbackMailer.deliver_callback_log, :after_only
    assert_includes CallbackMailer.deliver_callback_log, :around_only_before
    assert_includes CallbackMailer.deliver_callback_log, :around_only_after
    assert_not_includes CallbackMailer.deliver_callback_log, :before_except
    assert_not_includes CallbackMailer.deliver_callback_log, :after_except
    assert_not_includes CallbackMailer.deliver_callback_log, :around_except_before
    assert_not_includes CallbackMailer.deliver_callback_log, :around_except_after
  end

  test "deliver callbacks support except conditions" do
    CallbackMailer.another_test_message.deliver_now

    assert_includes CallbackMailer.deliver_callback_log, :before_except
    assert_includes CallbackMailer.deliver_callback_log, :after_except
    assert_includes CallbackMailer.deliver_callback_log, :around_except_before
    assert_includes CallbackMailer.deliver_callback_log, :around_except_after
    assert_not_includes CallbackMailer.deliver_callback_log, :before_only
    assert_not_includes CallbackMailer.deliver_callback_log, :after_only
    assert_not_includes CallbackMailer.deliver_callback_log, :around_only_before
    assert_not_includes CallbackMailer.deliver_callback_log, :around_only_after
  end

  test "deliver callbacks with only option follow the mailer action name" do
    CallbackMailer.test_raise_action.deliver_now
    assert_not_includes CallbackMailer.deliver_callback_log, [:only_action, "test_raise_action"]

    CallbackMailer.test_message.deliver_now
    assert_includes CallbackMailer.deliver_callback_log, [:only_action, "test_message"]
  end

  test "deliver callbacks with except option ignore missing actions by default" do
    CallbackMailer.test_raise_action.deliver_now
    assert_includes CallbackMailer.deliver_callback_log, [:except_action, "test_raise_action"]

    CallbackMailer.test_message.deliver_now
    assert_not_includes CallbackMailer.deliver_callback_log, [:except_action, "test_message"]
  end

  test "raise_on_missing_callback_actions raises for missing deliver callback actions" do
    CallbackMailer.raise_on_missing_callback_actions = true

    error = assert_raises(AbstractController::ActionNotFound) do
      CallbackMailer.test_raise_action.deliver_now
    end

    assert_match(/The non_existent_action action could not be found/, error.message)
  end

  test "around_deliver is called after rescue_from on action processing exceptions" do
    CallbackMailer.around_handles_error = true

    CallbackMailer.test_raise_action.deliver_now
    assert CallbackMailer.rescue_from_error
  end

  test "around_deliver is called before rescue_from on deliver! exceptions" do
    CallbackMailer.around_handles_error = true

    stub_any_instance(Mail::TestMailer, instance: Mail::TestMailer.new({})) do |instance|
      instance.stub(:deliver!, proc { raise "boom deliver exception" }) do
        CallbackMailer.test_message.deliver_now
      end
    end

    assert_kind_of CallbackMailer, CallbackMailer.after_deliver_instance
    assert_nil CallbackMailer.rescue_from_error
  end
end
