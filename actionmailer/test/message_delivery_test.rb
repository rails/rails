# frozen_string_literal: true

require "abstract_unit"
require "active_job"
require "mailers/delayed_mailer"

class MessageDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_logger = ActiveJob::Base.logger
    @previous_delivery_method = ActionMailer::Base.delivery_method
    @previous_deliver_later_queue_name = ActionMailer::Base.deliver_later_queue_name
    ActionMailer::Base.deliver_later_queue_name = :test_queue
    ActionMailer::Base.delivery_method = :test
    ActiveJob::Base.logger = Logger.new(nil)
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true

    DelayedMailer.last_error = nil
    DelayedMailer.last_rescue_from_instance = nil

    @mail = DelayedMailer.test_message(1, 2, 3)
  end

  teardown do
    ActionMailer::Base.deliveries.clear

    ActiveJob::Base.logger = @previous_logger
    ActionMailer::Base.delivery_method = @previous_delivery_method
    ActionMailer::Base.deliver_later_queue_name = @previous_deliver_later_queue_name

    DelayedMailer.last_error = nil
    DelayedMailer.last_rescue_from_instance = nil
  end

  test "should have a message" do
    assert @mail.message
  end

  test "its message should be a Mail::Message" do
    assert_equal Mail::Message, @mail.message.class
  end

  test "should respond to .deliver_later" do
    assert_respond_to @mail, :deliver_later
  end

  test "should respond to .deliver_later!" do
    assert_respond_to @mail, :deliver_later!
  end

  test "should respond to .deliver_now" do
    assert_respond_to @mail, :deliver_now
  end

  test "should respond to .deliver_now!" do
    assert_respond_to @mail, :deliver_now!
  end

  def test_should_enqueue_and_run_correctly_in_activejob
    @mail.deliver_later!
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "should enqueue the email with :deliver_now delivery method" do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3]) do
      @mail.deliver_later
    end
  end

  test "should enqueue the email with :deliver_now! delivery method" do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ["DelayedMailer", "test_message", "deliver_now!", 1, 2, 3]) do
      @mail.deliver_later!
    end
  end

  test "should enqueue a delivery with a delay" do
    travel_to Time.new(2004, 11, 24, 01, 04, 44) do
      assert_performed_with(job: ActionMailer::DeliveryJob, at: Time.current + 10.minutes, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3]) do
        @mail.deliver_later wait: 10.minutes
      end
    end
  end

  test "should enqueue a delivery at a specific time" do
    later_time = Time.current + 1.hour
    assert_performed_with(job: ActionMailer::DeliveryJob, at: later_time, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3]) do
      @mail.deliver_later wait_until: later_time
    end
  end

  test "should enqueue the job on the correct queue" do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3], queue: "test_queue") do
      @mail.deliver_later
    end
  end

  test "should enqueue the job with the correct delivery job" do
    old_delivery_job = DelayedMailer.delivery_job
    DelayedMailer.delivery_job = DummyJob

    assert_performed_with(job: DummyJob, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3]) do
      @mail.deliver_later
    end

    DelayedMailer.delivery_job = old_delivery_job
  end

  class DummyJob < ActionMailer::DeliveryJob; end

  test "can override the queue when enqueuing mail" do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ["DelayedMailer", "test_message", "deliver_now", 1, 2, 3], queue: "another_queue") do
      @mail.deliver_later(queue: :another_queue)
    end
  end

  test "deliver_later after accessing the message is disallowed" do
    @mail.message # Load the message, which calls the mailer method.

    assert_raise RuntimeError do
      @mail.deliver_later
    end
  end

  test "job delegates error handling to mailer" do
    # Superclass not rescued by mailer's rescue_from RuntimeError
    message = DelayedMailer.test_raise("StandardError")
    assert_raise(StandardError) { message.deliver_later }
    assert_nil DelayedMailer.last_error
    assert_nil DelayedMailer.last_rescue_from_instance

    # Rescued by mailer's rescue_from RuntimeError
    message = DelayedMailer.test_raise("DelayedMailerError")
    assert_nothing_raised { message.deliver_later }
    assert_equal "boom", DelayedMailer.last_error.message
    assert_kind_of DelayedMailer, DelayedMailer.last_rescue_from_instance
  end

  class DeserializationErrorFixture
    include GlobalID::Identification

    def self.find(_id)
      raise "boom, missing find"
    end

    attr_reader :id
    def initialize(id = 1)
      @id = id
    end

    def to_global_id(_options = {})
      super app: "foo"
    end
  end

  test "job delegates deserialization errors to mailer class" do
    # Inject an argument that can't be deserialized.
    message = DelayedMailer.test_message(DeserializationErrorFixture.new)

    # DeserializationError is raised, rescued, and delegated to the handler
    # on the mailer class.
    assert_nothing_raised { message.deliver_later }
    assert_equal DelayedMailer, DelayedMailer.last_rescue_from_instance
    assert_equal "Error while trying to deserialize arguments: boom, missing find", DelayedMailer.last_error.message
  end
end
