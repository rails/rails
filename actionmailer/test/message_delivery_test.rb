# encoding: utf-8
gem 'activejob'
require 'active_job'
require 'abstract_unit'
require 'minitest/mock'
require_relative 'mailers/delayed_mailer'

class MessageDeliveryTest < ActiveSupport::TestCase

  setup do
    @previous_logger = ActiveJob::Base.logger
    @previous_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    ActiveJob::Base.logger = Logger.new('/dev/null')
    @mail = DelayedMailer.test_message(1, 2, 3)
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
    ActionMailer::Base.delivery_method = @previous_delivery_method
  end

  test 'should be a MessageDelivery' do
    assert_equal @mail.class, ActionMailer::MessageDelivery
  end

  test 'its object should be a Mail::Message' do
    assert_equal @mail.__getobj__.class, Mail::Message
  end

  test 'should respond to .deliver' do
    assert_respond_to @mail, :deliver
  end

  test 'should respond to .deliver!' do
    assert_respond_to @mail, :deliver!
  end

  test 'should respond to .deliver_later' do
    assert_respond_to @mail, :deliver_later
  end

  test 'should respond to .deliver_later!' do
    assert_respond_to @mail, :deliver_later!
  end

  test 'should enqueue and run correctly in activejob' do
    @mail.deliver_later!
    assert_equal ActionMailer::Base.deliveries.size, 1
  end

  test 'should enqueue the email with :deliver delivery method' do
    ret = ActionMailer::DelayedDeliveryJob.stub :enqueue, ->(*args){ args } do
      @mail.deliver_later
    end
    assert_equal ret, ["DelayedMailer", "test_message", "deliver", 1, 2, 3]
  end

  test 'should enqueue the email with :deliver! delivery method' do
    ret = ActionMailer::DelayedDeliveryJob.stub :enqueue, ->(*args){ args } do
      @mail.deliver_later!
    end
    assert_equal ret, ["DelayedMailer", "test_message", "deliver!", 1, 2, 3]
  end

  test 'should enqueue a delivery with a delay' do
    ret = ActionMailer::DelayedDeliveryJob.stub :enqueue_in, ->(*args){ args } do
      @mail.deliver_later in: 600
    end
    assert_equal ret, [600, "DelayedMailer", "test_message", "deliver", 1, 2, 3]
  end

  test 'should enqueue a delivery at a specific time' do
    later_time = Time.now.to_i + 3600
    ret = ActionMailer::DelayedDeliveryJob.stub :enqueue_at, ->(*args){ args } do
      @mail.deliver_later at: later_time
    end
    assert_equal ret, [later_time, "DelayedMailer", "test_message", "deliver", 1, 2, 3]
  end

end
