require "abstract_unit"
require "mailers/base_mailer"
require "active_support/log_subscriber/test_helper"
require "action_mailer/log_subscriber"

class AMLogSubscriberTest < ActionMailer::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    ActionMailer::LogSubscriber.attach_to :action_mailer
  end

  class TestMailer < ActionMailer::Base
    def receive(mail)
      # Do nothing
    end
  end

  def set_logger(logger)
    ActionMailer::Base.logger = logger
  end

  def test_deliver_is_notified
    BaseMailer.welcome.deliver_now
    wait

    assert_equal(1, @logger.logged(:info).size)
    assert_match(/Sent mail to system@test.lindsaar.net/, @logger.logged(:info).first)

    assert_equal(2, @logger.logged(:debug).size)
    assert_match(/BaseMailer#welcome: processed outbound mail in [\d.]+ms/, @logger.logged(:debug).first)
    assert_match(/Welcome/, @logger.logged(:debug).second)
  ensure
    BaseMailer.deliveries.clear
  end

  def test_receive_is_notified
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email")
    TestMailer.receive(fixture)
    wait
    assert_equal(1, @logger.logged(:info).size)
    assert_match(/Received mail/, @logger.logged(:info).first)
    assert_equal(1, @logger.logged(:debug).size)
    assert_match(/Jamis/, @logger.logged(:debug).first)
  end
end
