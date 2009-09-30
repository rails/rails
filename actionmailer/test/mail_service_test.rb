# encoding: utf-8
require 'abstract_unit'

class FunkyPathMailer < ActionMailer::Base
  self.template_root = "#{File.dirname(__FILE__)}/fixtures/path.with.dots"

  def multipart_with_template_path_with_dots(recipient)
    recipients recipient
    subject    "Have a lovely picture"
    from       "Chad Fowler <chad@chadfowler.com>"
    attachment :content_type => "image/jpeg",
      :body => "not really a jpeg, we're only testing, after all"
  end
end

class TestMailer < ActionMailer::Base
  def signed_up(recipient)
    @recipients   = recipient
    @subject      = "[Signed up] Welcome #{recipient}"
    @from         = "system@loudthinking.com"
    @body["recipient"] = recipient
  end

  def cancelled_account(recipient)
    self.recipients = recipient
    self.subject    = "[Cancelled] Goodbye #{recipient}"
    self.from       = "system@loudthinking.com"
    self.sent_on    = Time.local(2004, 12, 12)
    self.body       = "Goodbye, Mr. #{recipient}"
  end

  def cc_bcc(recipient)
    recipients recipient
    subject    "testing bcc/cc"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    cc         "nobody@loudthinking.com"
    bcc        "root@loudthinking.com"
    body       "Nothing to see here."
  end

  def different_reply_to(recipient)
    recipients recipient
    subject    "testing reply_to"
    from       "system@loudthinking.com"
    sent_on    Time.local(2008, 5, 23)
    reply_to   "atraver@gmail.com"
    body       "Nothing to see here."
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

  def multipart_with_mime_version(recipient)
    recipients   recipient
    subject      "multipart with mime_version"
    from         "test@example.com"
    sent_on      Time.local(2004, 12, 12)
    mime_version "1.1"
    content_type "multipart/alternative"

    part "text/plain" do |p|
      p.body = "blah"
    end

    part "text/html" do |p|
      p.body = "<b>blah</b>"
    end
  end

  def multipart_with_utf8_subject(recipient)
    recipients   recipient
    subject      "Foo áëô îü"
    from         "test@example.com"
    charset      "utf-8"

    part "text/plain" do |p|
      p.body = "blah"
    end

    part "text/html" do |p|
      p.body = "<b>blah</b>"
    end
  end

  def explicitly_multipart_example(recipient, ct=nil)
    recipients   recipient
    subject      "multipart example"
    from         "test@example.com"
    sent_on      Time.local(2004, 12, 12)
    body         "plain text default"
    content_type ct if ct

    part "text/html" do |p|
      p.charset = "iso-8859-1"
      p.body = "blah"
    end

    attachment :content_type => "image/jpeg", :filename => "foo.jpg",
      :body => "123456789"
  end

  def implicitly_multipart_example(recipient, cs = nil, order = nil)
    @recipients = recipient
    @subject    = "multipart example"
    @from       = "test@example.com"
    @sent_on    = Time.local 2004, 12, 12
    @body       = { "recipient" => recipient }
    @charset    = cs if cs
    @implicit_parts_order = order if order
  end

  def implicitly_multipart_with_utf8
    recipients "no.one@nowhere.test"
    subject    "Foo áëô îü"
    from       "some.one@somewhere.test"
    template   "implicitly_multipart_example"
    body       ({ "recipient" => "no.one@nowhere.test" })
  end

  def html_mail(recipient)
    recipients   recipient
    subject      "html mail"
    from         "test@example.com"
    body         "<em>Emphasize</em> <strong>this</strong>"
    content_type "text/html"
  end

  def html_mail_with_underscores(recipient)
    subject      "html mail with underscores"
    body         %{<a href="http://google.com" target="_blank">_Google</a>}
  end

  def custom_template(recipient)
    recipients recipient
    subject    "[Signed up] Welcome #{recipient}"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    template   "signed_up"

    body["recipient"] = recipient
  end

  def custom_templating_extension(recipient)
    recipients recipient
    subject    "[Signed up] Welcome #{recipient}"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)

    body["recipient"] = recipient
  end

  def various_newlines(recipient)
    recipients   recipient
    subject      "various newlines"
    from         "test@example.com"
    body         "line #1\nline #2\rline #3\r\nline #4\r\r" +
                 "line #5\n\nline#6\r\n\r\nline #7"
  end

  def various_newlines_multipart(recipient)
    recipients   recipient
    subject      "various newlines multipart"
    from         "test@example.com"
    content_type "multipart/alternative"
    part :content_type => "text/plain", :body => "line #1\nline #2\rline #3\r\nline #4\r\r"
    part :content_type => "text/html", :body => "<p>line #1</p>\n<p>line #2</p>\r<p>line #3</p>\r\n<p>line #4</p>\r\r"
  end

  def nested_multipart(recipient)
    recipients   recipient
    subject      "nested multipart"
    from         "test@example.com"
    content_type "multipart/mixed"
    part :content_type => "multipart/alternative", :content_disposition => "inline", :headers => { "foo" => "bar" } do |p|
      p.part :content_type => "text/plain", :body => "test text\nline #2"
      p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>\nline #2"
    end
    attachment :content_type => "application/octet-stream",:filename => "test.txt", :body => "test abcdefghijklmnopqstuvwxyz"
  end

  def nested_multipart_with_body(recipient)
    recipients   recipient
    subject      "nested multipart with body"
    from         "test@example.com"
    content_type "multipart/mixed"
    part :content_type => "multipart/alternative", :content_disposition => "inline", :body => "Nothing to see here." do |p|
      p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>"
    end
  end

  def attachment_with_custom_header(recipient)
    recipients   recipient
    subject      "custom header in attachment"
    from         "test@example.com"
    content_type "multipart/related"
    part :content_type => "text/html", :body => 'yo'
    attachment :content_type => "image/jpeg",:filename => "test.jpeg", :body => "i am not a real picture", :headers => { 'Content-ID' => '<test@test.com>' }
  end

  def unnamed_attachment(recipient)
    recipients   recipient
    subject      "nested multipart"
    from         "test@example.com"
    content_type "multipart/mixed"
    part :content_type => "text/plain", :body => "hullo"
    attachment :content_type => "application/octet-stream", :body => "test abcdefghijklmnopqstuvwxyz"
  end

  def headers_with_nonalpha_chars(recipient)
    recipients   recipient
    subject      "nonalpha chars"
    from         "One: Two <test@example.com>"
    cc           "Three: Four <test@example.com>"
    bcc          "Five: Six <test@example.com>"
    body         "testing"
  end

  def custom_content_type_attributes
    recipients   "no.one@nowhere.test"
    subject      "custom content types"
    from         "some.one@somewhere.test"
    content_type "text/plain; format=flowed"
    body         "testing"
  end

  def return_path
    recipients   "no.one@nowhere.test"
    subject      "return path test"
    from         "some.one@somewhere.test"
    body         "testing"
    headers      "return-path" => "another@somewhere.test"
  end

  def body_ivar(recipient)
    recipients   recipient
    subject      "Body as a local variable"
    from         "test@example.com"
    body         :body => "foo", :bar => "baz"
  end

  class <<self
    attr_accessor :received_body
  end

  def receive(mail)
    self.class.received_body = mail.body
  end
end

class ActionMailerTest < Test::Unit::TestCase
  include ActionMailer::Quoting

  def encode( text, charset="utf-8" )
    quoted_printable( text, charset )
  end

  def new_mail( charset="utf-8" )
    mail = TMail::Mail.new
    mail.mime_version = "1.0"
    if charset
      mail.set_content_type "text", "plain", { "charset" => charset }
    end
    mail
  end

  # Replacing logger work around for mocha bug. Should be fixed in mocha 0.3.3
  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.deliveries = []

    @original_logger = TestMailer.logger
    @recipient = 'test@localhost'
  end

  def teardown
    TestMailer.logger = @original_logger
    restore_delivery_method
  end

  def test_nested_parts
    created = nil
    assert_nothing_raised { created = TestMailer.create_nested_multipart(@recipient)}
    assert_equal 2,created.parts.size
    assert_equal 2,created.parts.first.parts.size

    assert_equal "multipart/mixed", created.content_type
    assert_equal "multipart/alternative", created.parts.first.content_type
    assert_equal "bar", created.parts.first.header['foo'].to_s
    assert_nil created.parts.first.charset
    assert_equal "text/plain", created.parts.first.parts.first.content_type
    assert_equal "text/html", created.parts.first.parts[1].content_type
    assert_equal "application/octet-stream", created.parts[1].content_type
  end

  def test_nested_parts_with_body
    created = nil
    assert_nothing_raised { created = TestMailer.create_nested_multipart_with_body(@recipient)}
    assert_equal 1,created.parts.size
    assert_equal 2,created.parts.first.parts.size

    assert_equal "multipart/mixed", created.content_type
    assert_equal "multipart/alternative", created.parts.first.content_type
    assert_equal "Nothing to see here.", created.parts.first.parts.first.body
    assert_equal "text/plain", created.parts.first.parts.first.content_type
    assert_equal "text/html", created.parts.first.parts[1].content_type
  end

  def test_attachment_with_custom_header
    created = nil
    assert_nothing_raised { created = TestMailer.create_attachment_with_custom_header(@recipient)}
    assert_equal "<test@test.com>", created.parts[1].header['content-id'].to_s
  end

  def test_signed_up
    Time.stubs(:now => Time.now)

    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.now

    created = nil
    assert_nothing_raised { created = TestMailer.create_signed_up(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.deliver_signed_up(@recipient) }
    assert_not_nil ActionMailer::Base.deliveries.first
    assert_equal expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end

  def test_custom_template
    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.create_custom_template(@recipient) }
    assert_not_nil created
    assert_equal expected.encoded, created.encoded
  end

  def test_custom_templating_extension
    assert ActionView::Template.template_handler_extensions.include?("haml"), "haml extension was not registered"

    # N.b., custom_templating_extension.text.plain.haml is expected to be in fixtures/test_mailer directory
    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    # Stub the render method so no alternative renderers need be present.
    ActionView::Base.any_instance.stubs(:render).returns("Hello there, \n\nMr. #{@recipient}")

    # Now that the template is registered, there should be one part. The text/plain part.
    created = nil
    assert_nothing_raised { created = TestMailer.create_custom_templating_extension(@recipient) }
    assert_not_nil created
    assert_equal 2, created.parts.length
    assert_equal 'text/plain', created.parts[0].content_type
    assert_equal 'text/html', created.parts[1].content_type
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

  def test_reply_to
    expected = new_mail

    expected.to       = @recipient
    expected.subject  = "testing reply_to"
    expected.body     = "Nothing to see here."
    expected.from     = "system@loudthinking.com"
    expected.reply_to = "atraver@gmail.com"
    expected.date     = Time.local 2008, 5, 23

    created = nil
    assert_nothing_raised do
      created = TestMailer.create_different_reply_to @recipient
    end
    assert_not_nil created
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.deliver_different_reply_to @recipient
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

  def test_doesnt_raise_errors_when_raise_delivery_errors_is_false
    ActionMailer::Base.raise_delivery_errors = false
    TestMailer.any_instance.expects(:perform_delivery_test).raises(Exception)
    assert_nothing_raised { TestMailer.deliver_signed_up(@recipient) }
  end

  def test_performs_delivery_via_sendmail
    sm = mock()
    sm.expects(:print).with(anything)
    sm.expects(:flush)
    IO.expects(:popen).once.with('/usr/sbin/sendmail -i -t', 'w+').yields(sm)
    ActionMailer::Base.delivery_method = :sendmail
    TestMailer.deliver_signed_up(@recipient)
  end

  def test_delivery_logs_sent_mail
    mail = TestMailer.create_signed_up(@recipient)
    logger = mock()
    logger.expects(:info).with("Sent mail to #{@recipient}")
    logger.expects(:debug).with() do |logged_text|
      logged_text =~ /\[Signed up\] Welcome/
    end
    TestMailer.logger = logger
    TestMailer.deliver_signed_up(@recipient)
  end

  def test_unquote_quoted_printable_subject
    msg = <<EOF
From: me@example.com
Subject: =?utf-8?Q?testing_testing_=D6=A4?=
Content-Type: text/plain; charset=iso-8859-1

The body
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "testing testing \326\244", mail.subject
    assert_equal "=?utf-8?Q?testing_testing_=D6=A4?=", mail.quoted_subject
  end

  def test_unquote_7bit_subject
    msg = <<EOF
From: me@example.com
Subject: this == working?
Content-Type: text/plain; charset=iso-8859-1

The body
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "this == working?", mail.subject
    assert_equal "this == working?", mail.quoted_subject
  end

  def test_unquote_7bit_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 7bit

The=3Dbody
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "The=3Dbody", mail.body.strip
    assert_equal "The=3Dbody", mail.quoted_body.strip
  end

  def test_unquote_quoted_printable_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: quoted-printable

The=3Dbody
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "The=body", mail.body.strip
    assert_equal "The=3Dbody", mail.quoted_body.strip
  end

  def test_unquote_base64_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: base64

VGhlIGJvZHk=
EOF
    mail = TMail::Mail.parse(msg)
    assert_equal "The body", mail.body.strip
    assert_equal "VGhlIGJvZHk=", mail.quoted_body.strip
  end

  def test_extended_headers
    @recipient = "Grytøyr <test@localhost>"

    expected = new_mail "iso-8859-1"
    expected.to      = quote_address_if_necessary @recipient, "iso-8859-1"
    expected.subject = "testing extended headers"
    expected.body    = "Nothing to see here."
    expected.from    = quote_address_if_necessary "Grytøyr <stian1@example.net>", "iso-8859-1"
    expected.cc      = quote_address_if_necessary "Grytøyr <stian2@example.net>", "iso-8859-1"
    expected.bcc     = quote_address_if_necessary "Grytøyr <stian3@example.net>", "iso-8859-1"
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
    expected.to      = quote_address_if_necessary @recipient, "utf-8"
    expected.subject = "testing utf-8 body"
    expected.body    = "åœö blah"
    expected.from    = quote_address_if_necessary @recipient, "utf-8"
    expected.cc      = quote_address_if_necessary @recipient, "utf-8"
    expected.bcc     = quote_address_if_necessary @recipient, "utf-8"
    expected.date    = Time.local 2004, 12, 12

    created = TestMailer.create_utf8_body @recipient
    assert_match(/åœö blah/, created.encoded)
  end

  def test_multiple_utf8_recipients
    @recipient = ["\"Foo áëô îü\" <extended@example.net>", "\"Example Recipient\" <me@example.com>"]
    expected = new_mail "utf-8"
    expected.to      = quote_address_if_necessary @recipient, "utf-8"
    expected.subject = "testing utf-8 body"
    expected.body    = "åœö blah"
    expected.from    = quote_address_if_necessary @recipient.first, "utf-8"
    expected.cc      = quote_address_if_necessary @recipient, "utf-8"
    expected.bcc     = quote_address_if_necessary @recipient, "utf-8"
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

  def test_receive_attachments
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email2")
    mail = TMail::Mail.parse(fixture)
    attachment = mail.attachments.last
    assert_equal "smime.p7s", attachment.original_filename
    assert_equal "application/pkcs7-signature", attachment.content_type
  end

  def test_decode_attachment_without_charset
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email3")
    mail = TMail::Mail.parse(fixture)
    attachment = mail.attachments.last
    assert_equal 1026, attachment.read.length
  end

  def test_attachment_using_content_location
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email12")
    mail = TMail::Mail.parse(fixture)
    assert_equal 1, mail.attachments.length
    assert_equal "Photo25.jpg", mail.attachments.first.original_filename
  end

  def test_attachment_with_text_type
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email13")
    mail = TMail::Mail.parse(fixture)
    assert mail.has_attachments?
    assert_equal 1, mail.attachments.length
    assert_equal "hello.rb", mail.attachments.first.original_filename
  end

  def test_decode_part_without_content_type
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email4")
    mail = TMail::Mail.parse(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_decode_message_without_content_type
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email5")
    mail = TMail::Mail.parse(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_decode_message_with_incorrect_charset
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email6")
    mail = TMail::Mail.parse(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_multipart_with_mime_version
    mail = TestMailer.create_multipart_with_mime_version(@recipient)
    assert_equal "1.1", mail.mime_version
  end

  def test_multipart_with_utf8_subject
    mail = TestMailer.create_multipart_with_utf8_subject(@recipient)
    assert_match(/\nSubject: =\?utf-8\?Q\?Foo_.*?\?=/, mail.encoded)
  end

  def test_implicitly_multipart_with_utf8
    mail = TestMailer.create_implicitly_multipart_with_utf8
    assert_match(/\nSubject: =\?utf-8\?Q\?Foo_.*?\?=/, mail.encoded)
  end

  def test_explicitly_multipart_messages
    mail = TestMailer.create_explicitly_multipart_example(@recipient)
    assert_equal 3, mail.parts.length
    assert_nil mail.content_type
    assert_equal "text/plain", mail.parts[0].content_type

    assert_equal "text/html", mail.parts[1].content_type
    assert_equal "iso-8859-1", mail.parts[1].sub_header("content-type", "charset")
    assert_equal "inline", mail.parts[1].content_disposition

    assert_equal "image/jpeg", mail.parts[2].content_type
    assert_equal "attachment", mail.parts[2].content_disposition
    assert_equal "foo.jpg", mail.parts[2].sub_header("content-disposition", "filename")
    assert_equal "foo.jpg", mail.parts[2].sub_header("content-type", "name")
    assert_nil mail.parts[2].sub_header("content-type", "charset")
  end

  def test_explicitly_multipart_with_content_type
    mail = TestMailer.create_explicitly_multipart_example(@recipient, "multipart/alternative")
    assert_equal 3, mail.parts.length
    assert_equal "multipart/alternative", mail.content_type
  end

  def test_explicitly_multipart_with_invalid_content_type
    mail = TestMailer.create_explicitly_multipart_example(@recipient, "text/xml")
    assert_equal 3, mail.parts.length
    assert_nil mail.content_type
  end

  def test_implicitly_multipart_messages
    assert ActionView::Template.template_handler_extensions.include?("bak"), "bak extension was not registered"

    mail = TestMailer.create_implicitly_multipart_example(@recipient)
    assert_equal 3, mail.parts.length
    assert_equal "1.0", mail.mime_version
    assert_equal "multipart/alternative", mail.content_type
    assert_equal "text/yaml", mail.parts[0].content_type
    assert_equal "utf-8", mail.parts[0].sub_header("content-type", "charset")
    assert_equal "text/plain", mail.parts[1].content_type
    assert_equal "utf-8", mail.parts[1].sub_header("content-type", "charset")
    assert_equal "text/html", mail.parts[2].content_type
    assert_equal "utf-8", mail.parts[2].sub_header("content-type", "charset")
  end

  def test_implicitly_multipart_messages_with_custom_order
    assert ActionView::Template.template_handler_extensions.include?("bak"), "bak extension was not registered"

    mail = TestMailer.create_implicitly_multipart_example(@recipient, nil, ["text/yaml", "text/plain"])
    assert_equal 3, mail.parts.length
    assert_equal "text/html", mail.parts[0].content_type
    assert_equal "text/plain", mail.parts[1].content_type
    assert_equal "text/yaml", mail.parts[2].content_type
  end

  def test_implicitly_multipart_messages_with_charset
    mail = TestMailer.create_implicitly_multipart_example(@recipient, 'iso-8859-1')

    assert_equal "multipart/alternative", mail.header['content-type'].body

    assert_equal 'iso-8859-1', mail.parts[0].sub_header("content-type", "charset")
    assert_equal 'iso-8859-1', mail.parts[1].sub_header("content-type", "charset")
    assert_equal 'iso-8859-1', mail.parts[2].sub_header("content-type", "charset")
  end

  def test_html_mail
    mail = TestMailer.create_html_mail(@recipient)
    assert_equal "text/html", mail.content_type
  end

  def test_html_mail_with_underscores
    mail = TestMailer.create_html_mail_with_underscores(@recipient)
    assert_equal %{<a href="http://google.com" target="_blank">_Google</a>}, mail.body
  end

  def test_various_newlines
    mail = TestMailer.create_various_newlines(@recipient)
    assert_equal("line #1\nline #2\nline #3\nline #4\n\n" +
                 "line #5\n\nline#6\n\nline #7", mail.body)
  end

  def test_various_newlines_multipart
    mail = TestMailer.create_various_newlines_multipart(@recipient)
    assert_equal "line #1\nline #2\nline #3\nline #4\n\n", mail.parts[0].body
    assert_equal "<p>line #1</p>\n<p>line #2</p>\n<p>line #3</p>\n<p>line #4</p>\n\n", mail.parts[1].body
  end

  def test_headers_removed_on_smtp_delivery
    ActionMailer::Base.delivery_method = :smtp
    TestMailer.deliver_cc_bcc(@recipient)
    assert MockSMTP.deliveries[0][2].include?("root@loudthinking.com")
    assert MockSMTP.deliveries[0][2].include?("nobody@loudthinking.com")
    assert MockSMTP.deliveries[0][2].include?(@recipient)
    assert_match %r{^Cc: nobody@loudthinking.com}, MockSMTP.deliveries[0][0]
    assert_match %r{^To: #{@recipient}}, MockSMTP.deliveries[0][0]
    assert_no_match %r{^Bcc: root@loudthinking.com}, MockSMTP.deliveries[0][0]
  end

  def test_recursive_multipart_processing
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email7")
    mail = TMail::Mail.parse(fixture)
    assert_equal "This is the first part.\n\nAttachment: test.rb\nAttachment: test.pdf\n\n\nAttachment: smime.p7s\n", mail.body
  end

  def test_decode_encoded_attachment_filename
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email8")
    mail = TMail::Mail.parse(fixture)
    attachment = mail.attachments.last

    expected = "01 Quien Te Dij\212at. Pitbull.mp3"
    expected.force_encoding(Encoding::ASCII_8BIT) if expected.respond_to?(:force_encoding)

    assert_equal expected, attachment.original_filename
  end

  def test_wrong_mail_header
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email9")
    assert_raise(TMail::SyntaxError) { TMail::Mail.parse(fixture) }
  end

  def test_decode_message_with_unknown_charset
    fixture = File.read(File.dirname(__FILE__) + "/fixtures/raw_email10")
    mail = TMail::Mail.parse(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_empty_header_values_omitted
    result = TestMailer.create_unnamed_attachment(@recipient).encoded
    assert_match %r{Content-Type: application/octet-stream[^;]}, result
    assert_match %r{Content-Disposition: attachment[^;]}, result
  end

  def test_headers_with_nonalpha_chars
    mail = TestMailer.create_headers_with_nonalpha_chars(@recipient)
    assert !mail.from_addrs.empty?
    assert !mail.cc_addrs.empty?
    assert !mail.bcc_addrs.empty?
    assert_match(/:/, mail.from_addrs.to_s)
    assert_match(/:/, mail.cc_addrs.to_s)
    assert_match(/:/, mail.bcc_addrs.to_s)
  end

  def test_deliver_with_mail_object
    mail = TestMailer.create_headers_with_nonalpha_chars(@recipient)
    assert_nothing_raised { TestMailer.deliver(mail) }
    assert_equal 1, TestMailer.deliveries.length
  end

  def test_multipart_with_template_path_with_dots
    mail = FunkyPathMailer.create_multipart_with_template_path_with_dots(@recipient)
    assert_equal 2, mail.parts.length
    assert_equal 'text/plain', mail.parts[0].content_type
    assert_equal 'utf-8', mail.parts[0].charset
  end

  def test_custom_content_type_attributes
    mail = TestMailer.create_custom_content_type_attributes
    assert_match %r{format=flowed}, mail['content-type'].to_s
    assert_match %r{charset=utf-8}, mail['content-type'].to_s
  end

  def test_return_path_with_create
    mail = TestMailer.create_return_path
    assert_equal "<another@somewhere.test>", mail['return-path'].to_s
  end

  def test_return_path_with_deliver
    ActionMailer::Base.delivery_method = :smtp
    TestMailer.deliver_return_path
    assert_match %r{^Return-Path: <another@somewhere.test>}, MockSMTP.deliveries[0][0]
    assert_equal "another@somewhere.test", MockSMTP.deliveries[0][1].to_s
  end

  def test_body_is_stored_as_an_ivar
    mail = TestMailer.create_body_ivar(@recipient)
    assert_equal "body: foo\nbar: baz", mail.body
  end

  def test_starttls_is_enabled_if_supported
    ActionMailer::Base.smtp_settings[:enable_starttls_auto] = true
    MockSMTP.any_instance.expects(:respond_to?).with(:enable_starttls_auto).returns(true)
    MockSMTP.any_instance.expects(:enable_starttls_auto)
    ActionMailer::Base.delivery_method = :smtp
    TestMailer.deliver_signed_up(@recipient)
  end

  def test_starttls_is_disabled_if_not_supported
    ActionMailer::Base.smtp_settings[:enable_starttls_auto] = true
    MockSMTP.any_instance.expects(:respond_to?).with(:enable_starttls_auto).returns(false)
    MockSMTP.any_instance.expects(:enable_starttls_auto).never
    ActionMailer::Base.delivery_method = :smtp
    TestMailer.deliver_signed_up(@recipient)
  end

  def test_starttls_is_not_enabled
    ActionMailer::Base.smtp_settings[:enable_starttls_auto] = false
    MockSMTP.any_instance.expects(:respond_to?).never
    MockSMTP.any_instance.expects(:enable_starttls_auto).never
    ActionMailer::Base.delivery_method = :smtp
    TestMailer.deliver_signed_up(@recipient)
  ensure
    ActionMailer::Base.smtp_settings[:enable_starttls_auto] = true
  end
end

class InheritableTemplateRootTest < Test::Unit::TestCase
  def test_attr
    expected = "#{File.dirname(__FILE__)}/fixtures/path.with.dots"
    assert_equal expected, FunkyPathMailer.template_root.to_s

    sub = Class.new(FunkyPathMailer)
    sub.template_root = 'test/path'

    assert_equal 'test/path', sub.template_root.to_s
    assert_equal expected, FunkyPathMailer.template_root.to_s
  end
end

class MethodNamingTest < Test::Unit::TestCase
  class TestMailer < ActionMailer::Base
    def send
      body 'foo'
    end
  end

  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def teardown
    restore_delivery_method
  end

  def test_send_method
    assert_nothing_raised do
      assert_emails 1 do
        TestMailer.deliver_send
      end
    end
  end
end

class RespondToTest < Test::Unit::TestCase
  class RespondToMailer < ActionMailer::Base; end

  def setup
    set_delivery_method :test
  end

  def teardown
    restore_delivery_method
  end

  def test_should_respond_to_new
    assert RespondToMailer.respond_to?(:new)
  end

  def test_should_respond_to_create_with_template_suffix
    assert RespondToMailer.respond_to?(:create_any_old_template)
  end

  def test_should_respond_to_deliver_with_template_suffix
    assert RespondToMailer.respond_to?(:deliver_any_old_template)
  end

  def test_should_not_respond_to_new_with_template_suffix
    assert !RespondToMailer.respond_to?(:new_any_old_template)
  end

  def test_should_not_respond_to_create_with_template_suffix_unless_it_is_separated_by_an_underscore
    assert !RespondToMailer.respond_to?(:createany_old_template)
  end

  def test_should_not_respond_to_deliver_with_template_suffix_unless_it_is_separated_by_an_underscore
    assert !RespondToMailer.respond_to?(:deliverany_old_template)
  end

  def test_should_not_respond_to_create_with_template_suffix_if_it_begins_with_a_uppercase_letter
    assert !RespondToMailer.respond_to?(:create_Any_old_template)
  end

  def test_should_not_respond_to_deliver_with_template_suffix_if_it_begins_with_a_uppercase_letter
    assert !RespondToMailer.respond_to?(:deliver_Any_old_template)
  end

  def test_should_not_respond_to_create_with_template_suffix_if_it_begins_with_a_digit
    assert !RespondToMailer.respond_to?(:create_1_template)
  end

  def test_should_not_respond_to_deliver_with_template_suffix_if_it_begins_with_a_digit
    assert !RespondToMailer.respond_to?(:deliver_1_template)
  end

  def test_should_not_respond_to_method_where_deliver_is_not_a_suffix
    assert !RespondToMailer.respond_to?(:foo_deliver_template)
  end

  def test_should_still_raise_exception_with_expected_message_when_calling_an_undefined_method
    error = assert_raise NoMethodError do
      RespondToMailer.not_a_method
    end

    assert_match /undefined method.*not_a_method/, error.message
  end
end
