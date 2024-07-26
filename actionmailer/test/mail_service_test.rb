$:.unshift(File.dirname(__FILE__) + "/../lib/")

require 'test/unit'
require 'action_mailer'

class TestMailer < ActionMailer::Base
  def signed_up(recipient)
    @recipients   = recipient
    @subject      = "[Signed up] Welcome #{recipient}"
    @from         = "system@loudthinking.com"
    @sent_on      = Time.local(2004, 12, 12)
    @body["recipient"] = recipient
  end

  def cancelled_account(recipient)
    @recipients = recipient
    @subject    = "[Cancelled] Goodbye #{recipient}"
    @from       = "system@loudthinking.com"
    @sent_on    = Time.local(2004, 12, 12)
    @body       = "Goodbye, Mr. #{recipient}"
  end
end

TestMailer.template_root = File.dirname(__FILE__) + "/fixtures"

class ActionMailerTest < Test::Unit::TestCase
  def test_signed_up
    expected = TMail::Mail.new
    expected.to      = "david@loudthinking.com"
    expected.subject = "[Signed up] Welcome david@loudthinking.com"
    expected.body    = "Hello there, \n\nMr. david@loudthinking.com"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    assert_equal expected.encoded, TestMailer.create_signed_up("david@loudthinking.com").encoded
  end
  
  def test_cancelled_account
    expected = TMail::Mail.new
    expected.to      = "david@loudthinking.com"
    expected.subject = "[Cancelled] Goodbye david@loudthinking.com"
    expected.body    = "Goodbye, Mr. david@loudthinking.com"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    assert_equal expected.encoded, TestMailer.create_cancelled_account("david@loudthinking.com").encoded
  end
  
  def test_instances_are_nil
    assert_nil ActionMailer::Base.new
    assert_nil TestMailer.new
  end
end