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

  def cc_bcc(recipient)
    @recipients = recipient
    @subject    = "testing bcc/cc"
    @from       = "system@loudthinking.com"
    @sent_on    = Time.local 2004, 12, 12
    @cc         = "nobody@loudthinking.com"
    @bcc        = "root@loudthinking.com"
    @body       = "Nothing to see here."
  end

  def iso_charset(recipient)
    @recipients = recipient
    @subject    = "testing iso charsets"
    @from       = "system@loudthinking.com"
    @sent_on    = Time.local 2004, 12, 12
    @cc         = "nobody@loudthinking.com"
    @bcc        = "root@loudthinking.com"
    @body       = "Nothing to see here."
    @charset    = "iso-8859-1"
  end

  def unencoded_subject(recipient)
    @recipients = recipient
    @subject    = "testing unencoded subject"
    @from       = "system@loudthinking.com"
    @sent_on    = Time.local 2004, 12, 12
    @cc         = "nobody@loudthinking.com"
    @bcc        = "root@loudthinking.com"
    @body       = "Nothing to see here."
    @encode_subject = false
  end

end

TestMailer.template_root = File.dirname(__FILE__) + "/fixtures"

class ActionMailerTest < Test::Unit::TestCase

  def encode( text, charset="utf-8" )
    ActionMailer::Base.quoted_printable( text, charset )
  end

  def new_mail( charset="utf-8" )
    mail = TMail::Mail.new
    if charset
      mail.set_content_type "text", "plain", { "charset" => charset }
    end
    mail
  end

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @recipient = 'test@localhost'
  end

  def test_signed_up
    expected = new_mail
    expected.to      = @recipient
    expected.subject = encode "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.create_signed_up(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.deliver_signed_up(@recipient) }
    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end
  
  def test_cancelled_account
    expected = new_mail
    expected.to      = @recipient
    expected.subject = encode "[Cancelled] Goodbye #{@recipient}"
    expected.body    = "Goodbye, Mr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.create_cancelled_account(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.deliver_cancelled_account(@recipient) }
    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end
  
  def test_cc_bcc
    expected = new_mail
    expected.to      = @recipient
    expected.subject = encode "testing bcc/cc"
    expected.body    = "Nothing to see here."
    expected.from    = "system@loudthinking.com"
    expected.cc      = "nobody@loudthinking.com"
    expected.bcc     = "root@loudthinking.com"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.create_cc_bcc @recipient
    end
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.deliver_cc_bcc @recipient
    end

    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end

  def test_iso_charset
    expected = new_mail( "iso-8859-1" )
    expected.to      = @recipient
    expected.subject = encode "testing iso charsets", "iso-8859-1"
    expected.body    = "Nothing to see here."
    expected.from    = "system@loudthinking.com"
    expected.cc      = "nobody@loudthinking.com"
    expected.bcc     = "root@loudthinking.com"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.create_iso_charset @recipient
    end
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.deliver_iso_charset @recipient
    end

    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end

  def test_unencoded_subject
    expected = new_mail
    expected.to      = @recipient
    expected.subject = "testing unencoded subject"
    expected.body    = "Nothing to see here."
    expected.from    = "system@loudthinking.com"
    expected.cc      = "nobody@loudthinking.com"
    expected.bcc     = "root@loudthinking.com"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.create_unencoded_subject @recipient
    end
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.deliver_unencoded_subject @recipient
    end

    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end

  def test_instances_are_nil
    assert_nil ActionMailer::Base.new
    assert_nil TestMailer.new
  end

  def test_deliveries_array
    assert_not_nil ActionMailer::Base.deliveries
    assert_equal 0, ActionMailer::Base.deliveries.size
    TestMailer.deliver_signed_up(@recipient)
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not_nil ActionMailer::Base.deliveries.first
  end

  def test_perform_deliveries_flag
    ActionMailer::Base.perform_deliveries = false
    TestMailer.deliver_signed_up(@recipient)
    assert_equal 0, ActionMailer::Base.deliveries.size
    ActionMailer::Base.perform_deliveries = true
    TestMailer.deliver_signed_up(@recipient)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

end

