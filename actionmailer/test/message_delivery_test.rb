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
    ActiveJob::Base.logger = Logger.new(nil)
    @mail = DelayedMailer.test_message(1, 2, 3)
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActiveJob::Base.logger = @previous_logger
    ActionMailer::Base.delivery_method = @previous_delivery_method
  end

  test 'should have a message' do
    assert @mail.message
  end

  test 'its message should be a Mail::Message' do
    assert_equal Mail::Message , @mail.message.class
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
    assert_equal 1 , ActionMailer::Base.deliveries.size
  end

  test 'should enqueue the email with :deliver delivery method' do
    ret = ActionMailer::DeliveryJob.stub :enqueue, ->(*args){ args } do
      @mail.deliver_later
    end
    assert_equal ['DelayedMailer', 'test_message', 'deliver', 1, 2, 3], ret
  end

  test 'should enqueue the email with :deliver! delivery method' do
    ret = ActionMailer::DeliveryJob.stub :enqueue, ->(*args){ args } do
      @mail.deliver_later!
    end
    assert_equal ['DelayedMailer', 'test_message', 'deliver!', 1, 2, 3], ret
  end

  test 'should enqueue a delivery with a delay' do
    ret = ActionMailer::DeliveryJob.stub :enqueue_in, ->(*args){ args } do
      @mail.deliver_later in: 600
    end
    assert_equal [600, 'DelayedMailer', 'test_message', 'deliver', 1, 2, 3], ret
  end

  test 'should enqueue a delivery at a specific time' do
    later_time = Time.now.to_i + 3600
    ret = ActionMailer::DeliveryJob.stub :enqueue_at, ->(*args){ args } do
      @mail.deliver_later at: later_time
    end
    assert_equal [later_time, 'DelayedMailer', 'test_message', 'deliver', 1, 2, 3], ret
  end

end
