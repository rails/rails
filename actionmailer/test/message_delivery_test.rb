require 'abstract_unit'
require 'active_job'
require 'mailers/delayed_mailer'

class MessageDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_logger = ActiveJob::Base.logger
    @previous_delivery_method = ActionMailer::Base.delivery_method
    @previous_deliver_later_queue_name = ActionMailer::Base.deliver_later_queue_name
    ActionMailer::Base.deliver_later_queue_name = :test_queue
    ActionMailer::Base.delivery_method = :test
    ActiveJob::Base.logger = Logger.new(nil)
    @mail = DelayedMailer.test_message(1, 2, 3)
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
    ActionMailer::Base.delivery_method = @previous_delivery_method
    ActionMailer::Base.deliver_later_queue_name = @previous_deliver_later_queue_name
  end

  test 'should have a message' do
    assert @mail.message
  end

  test 'its message should be a Mail::Message' do
    assert_equal Mail::Message , @mail.message.class
  end

  test 'should respond to .deliver_later' do
    assert_respond_to @mail, :deliver_later
  end

  test 'should respond to .deliver_later!' do
    assert_respond_to @mail, :deliver_later!
  end

  test 'should respond to .deliver_now' do
    assert_respond_to @mail, :deliver_now
  end

  test 'should respond to .deliver_now!' do
    assert_respond_to @mail, :deliver_now!
  end

  def test_should_enqueue_and_run_correctly_in_activejob
    @mail.deliver_later!
    assert_equal 1, ActionMailer::Base.deliveries.size
  ensure
    ActionMailer::Base.deliveries.clear
  end

  test 'should enqueue the email with :deliver_now delivery method' do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ['DelayedMailer', 'test_message', 'deliver_now', 1, 2, 3]) do
      @mail.deliver_later
    end
  end

  test 'should enqueue the email with :deliver_now! delivery method' do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ['DelayedMailer', 'test_message', 'deliver_now!', 1, 2, 3]) do
      @mail.deliver_later!
    end
  end

  test 'should enqueue a delivery with a delay' do
    travel_to Time.new(2004, 11, 24, 01, 04, 44) do
      assert_performed_with(job: ActionMailer::DeliveryJob, at: Time.current.to_f+600.seconds, args: ['DelayedMailer', 'test_message', 'deliver_now', 1, 2, 3]) do
        @mail.deliver_later wait: 600.seconds
      end
    end
  end

  test 'should enqueue a delivery at a specific time' do
    later_time = Time.now.to_f + 3600
    assert_performed_with(job: ActionMailer::DeliveryJob, at: later_time, args: ['DelayedMailer', 'test_message', 'deliver_now', 1, 2, 3]) do
      @mail.deliver_later wait_until: later_time
    end
  end

  test 'should enqueue the job on the correct queue' do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ['DelayedMailer', 'test_message', 'deliver_now', 1, 2, 3], queue: "test_queue") do
      @mail.deliver_later
    end
  end

  test 'can override the queue when enqueuing mail' do
    assert_performed_with(job: ActionMailer::DeliveryJob, args: ['DelayedMailer', 'test_message', 'deliver_now', 1, 2, 3], queue: "another_queue") do
      @mail.deliver_later(queue: :another_queue)
    end
  end

  test 'deliver_later after accessing the message is disallowed' do
    @mail.message # Load the message, which calls the mailer method.

    assert_raise RuntimeError do
      @mail.deliver_later
    end
  end
end
