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
    @subject    = "testing isø charsets"
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
  end

  def extended_headers(recipient)
    @recipients = recipient
    @subject    = "testing extended headers"
    @from       = "Grytøyr <stian1@example.net>"
    @sent_on    = Time.local 2004, 12, 12
    @cc         = "Grytøyr <stian2@example.net>"
    @bcc        = "Grytøyr <stian3@example.net>"
    @body       = "Nothing to see here."
    @charset    = "iso-8859-1"
  end

  def utf8_body(recipient)
    @recipients = recipient
    @subject    = "testing utf-8 body"
    @from       = "Foo áëô îü <extended@example.net>"
    @sent_on    = Time.local 2004, 12, 12
    @cc         = "Foo áëô îü <extended@example.net>"
    @bcc        = "Foo áëô îü <extended@example.net>"
    @body       = "åœö blah"
    @charset    = "utf-8"
  end

  class <<self
    attr_accessor :received_body
  end

  def receive(mail)
    self.class.received_body = mail.body
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
    expected.subject = "[Signed up] Welcome #{@recipient}"
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
    expected.subject = "[Cancelled] Goodbye #{@recipient}"
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
    expected.subject = "testing bcc/cc"
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
    expected.subject = encode "testing isø charsets", "iso-8859-1"
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

  def test_unquote_subject
    msg = <<EOF
From: me@example.com
Subject: =?utf-8?Q?testing_testing_=D6=A4?=
Content-Type: text/plain; charset=iso-8859-1

This_is_a_test
2 + 2 =3D 4
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "testing testing \326\244", mail.subject
    assert_equal "=?utf-8?Q?testing_testing_=D6=A4?=", mail.quoted_subject
    assert_equal "This is a test\n2 + 2 = 4\n", mail.body
    assert_equal "This_is_a_test\n2 + 2 =3D 4\n", mail.quoted_body
  end

  def test_extended_headers
    @recipient = "Grytøyr <test@localhost>"

    expected = new_mail "iso-8859-1"
    expected.to      = TestMailer.quote_address_if_necessary @recipient, "iso-8859-1"
    expected.subject = "testing extended headers"
    expected.body    = "Nothing to see here."
    expected.from    = TestMailer.quote_address_if_necessary "Grytøyr <stian1@example.net>", "iso-8859-1"
    expected.cc      = TestMailer.quote_address_if_necessary "Grytøyr <stian2@example.net>", "iso-8859-1"
    expected.bcc     = TestMailer.quote_address_if_necessary "Grytøyr <stian3@example.net>", "iso-8859-1"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.create_extended_headers @recipient
    end

    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.deliver_extended_headers @recipient
    end

    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end
  
  def test_utf8_body_is_not_quoted
    @recipient = "Foo áëô îü <extended@example.net>"
    expected = new_mail "utf-8"
    expected.to      = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.subject = "testing utf-8 body"
    expected.body    = "åœö blah"
    expected.from    = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.cc      = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.bcc     = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.date    = Time.local 2004, 12, 12

    created = TestMailer.create_utf8_body @recipient
    assert_match(/åœö blah/, created.encoded)
  end

  def test_multiple_utf8_recipients
    @recipient = ["\"Foo áëô îü\" <extended@example.net>", "\"Example Recipient\" <me@example.com>"]
    expected = new_mail "utf-8"
    expected.to      = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.subject = "testing utf-8 body"
    expected.body    = "åœö blah"
    expected.from    = TestMailer.quote_address_if_necessary @recipient.first, "utf-8"
    expected.cc      = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.bcc     = TestMailer.quote_address_if_necessary @recipient, "utf-8"
    expected.date    = Time.local 2004, 12, 12

    created = TestMailer.create_utf8_body @recipient
    assert_match(/\nFrom: =\?utf-8\?Q\?Foo_.*?\?= <extended@example.net>\r/, created.encoded)
    assert_match(/\nTo: =\?utf-8\?Q\?Foo_.*?\?= <extended@example.net>, Example Recipient <me/, created.encoded)
  end

  def test_receive_decodes_base64_encoded_mail
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email")
    TestMailer.receive(fixture)
    assert_match(/Jamis/, TestMailer.received_body)
  end

end

