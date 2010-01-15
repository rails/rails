require "abstract_unit"
require "rails/subscriber/test_helper"
require "action_mailer/railties/subscriber"

module SubscriberTest
  Rails::Subscriber.add(:action_mailer, ActionMailer::Railties::Subscriber.new)

  class TestMailer < ActionMailer::Base
    def basic
      recipients "somewhere@example.com"
      subject    "basic"
      from       "basic@example.com"
      render :text => "Hello world"
    end

    def receive(mail)
      # Do nothing
    end
  end

  def set_logger(logger)
    ActionMailer::Base.logger = logger
  end

  def test_deliver_is_notified
    TestMailer.deliver_basic
    wait
    assert_equal 1, @logger.logged(:info).size
    assert_match /Sent mail to somewhere@example.com/, @logger.logged(:info).first
    assert_equal 1, @logger.logged(:debug).size
    assert_match /Hello world/, @logger.logged(:debug).first
  end

  def test_receive_is_notified
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email")
    TestMailer.receive(fixture)
    wait
    assert_equal 1, @logger.logged(:info).size
    assert_match /Received mail/, @logger.logged(:info).first
    assert_equal 1, @logger.logged(:debug).size
    assert_match /Jamis/, @logger.logged(:debug).first
  end

  class SyncSubscriberTest < ActionMailer::TestCase
    include Rails::Subscriber::SyncTestHelper
    include SubscriberTest
  end

  class AsyncSubscriberTest < ActionMailer::TestCase
    include Rails::Subscriber::AsyncTestHelper
    include SubscriberTest
  end
end