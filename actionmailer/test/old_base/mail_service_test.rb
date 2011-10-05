# encoding: utf-8
require 'abstract_unit'

class FunkyPathMailer < ActionMailer::Base
  self.view_paths = "#{File.dirname(__FILE__)}/../fixtures/path.with.dots"

  def multipart_with_template_path_with_dots(recipient)
    recipients recipient
    subject    "This path has dots"
    from       "Chad Fowler <chad@chadfowler.com>"
    attachment :content_type => "text/plain",
      :data => "dots dots dots..."
  end
end

class TestMailer < ActionMailer::Base
  def signed_up(recipient)
    recipients recipient
    subject    "[Signed up] Welcome #{recipient}"
    from       "system@loudthinking.com"

    @recipient = recipient
  end

  def cancelled_account(recipient)
    recipients recipient
    subject    "[Cancelled] Goodbye #{recipient}"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    body       "Goodbye, Mr. #{recipient}"
  end

  def from_with_name
    from       "System <system@loudthinking.com>"
    recipients "root@loudthinking.com"
    body       "Nothing to see here."
  end

  def from_without_name
    from       "system@loudthinking.com"
    recipients "root@loudthinking.com"
    body       "Nothing to see here."
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
    recipients recipient
    subject    "testing isø charsets"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    cc         "nobody@loudthinking.com"
    bcc        "root@loudthinking.com"
    charset    "iso-8859-1"

    body       "Nothing to see here."
  end

  def unencoded_subject(recipient)
    recipients recipient
    subject    "testing unencoded subject"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    cc         "nobody@loudthinking.com"
    bcc        "root@loudthinking.com"

    body       "Nothing to see here."
  end

  def extended_headers(recipient)
    recipients recipient
    subject    "testing extended headers"
    from       "Grytøyr <stian1@example.net>"
    sent_on    Time.local(2004, 12, 12)
    cc         "Grytøyr <stian2@example.net>"
    bcc        "Grytøyr <stian3@example.net>"
    charset    "iso-8859-1"

    body       "Nothing to see here."
  end

  def utf8_body(recipient)
    recipients recipient
    subject    "testing utf-8 body"
    from       "Foo áëô îü <extended@example.net>"
    sent_on    Time.local(2004, 12, 12)
    cc         "Foo áëô îü <extended@example.net>"
    bcc        "Foo áëô îü <extended@example.net>"
    charset    "UTF-8"

    body       "åœö blah"
  end

  def multipart_with_mime_version(recipient)
    recipients   recipient
    subject      "multipart with mime_version"
    from         "test@example.com"
    sent_on      Time.local(2004, 12, 12)
    mime_version "1.1"
    content_type "multipart/alternative"

    part "text/plain" do |p|
      p.body = render(:text => "blah")
    end

    part "text/html" do |p|
      p.body = render(:inline => "<%= content_tag(:b, 'blah') %>")
    end
  end

  def multipart_with_utf8_subject(recipient)
    recipients   recipient
    subject      "Foo áëô îü"
    from         "test@example.com"
    charset      "UTF-8"

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
    content_type ct if ct

    part "text/html" do |p|
      p.charset = "iso-8859-1"
      p.body = "blah"
    end

    attachment :content_type => "image/jpeg", :filename => File.join(File.dirname(__FILE__), "fixtures", "attachments", "foo.jpg"),
      :data => "123456789"

    body       "plain text default"
  end

  def implicitly_multipart_example(recipient, cs = nil, order = nil)
    recipients recipient
    subject    "multipart example"
    from       "test@example.com"
    sent_on    Time.local(2004, 12, 12)

    @charset = cs if cs
    @recipient = recipient
    @implicit_parts_order = order if order
  end

  def implicitly_multipart_with_utf8
    recipients "no.one@nowhere.test"
    subject    "Foo áëô îü"
    from       "some.one@somewhere.test"
    template   "implicitly_multipart_example"

    @recipient = "no.one@nowhere.test"
  end

  def html_mail(recipient)
    recipients   recipient
    subject      "html mail"
    from         "test@example.com"
    content_type "text/html"

    body       "<em>Emphasize</em> <strong>this</strong>"
  end

  def html_mail_with_underscores(recipient)
    subject      "html mail with underscores"
    body       %{<a href="http://google.com" target="_blank">_Google</a>}
  end

  def custom_template(recipient)
    recipients recipient
    subject    "[Signed up] Welcome #{recipient}"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)
    template   "signed_up"

    @recipient = recipient
  end

  def custom_templating_extension(recipient)
    recipients recipient
    subject    "[Signed up] Welcome #{recipient}"
    from       "system@loudthinking.com"
    sent_on    Time.local(2004, 12, 12)

    @recipient = recipient
  end

  def various_newlines(recipient)
    recipients   recipient
    subject      "various newlines"
    from         "test@example.com"

    body       "line #1\nline #2\rline #3\r\nline #4\r\r" +
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

    part :content_type => "multipart/alternative", :content_disposition => "inline", "foo" => "bar" do |p|
      p.part :content_type => "text/plain", :body => "test text\nline #2"
      p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>\nline #2"
    end

    attachment :content_type => "application/octet-stream", :filename => "test.txt", :data => "test abcdefghijklmnopqstuvwxyz"
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
    part         :content_type => "text/html", :body => 'yo'
    attachment   :content_type => "image/jpeg", :filename => File.join(File.dirname(__FILE__), "fixtures", "attachments", "test.jpg"), :data => "i am not a real picture", 'Content-ID' => '<test@test.com>'
  end

  def unnamed_attachment(recipient)
    recipients   recipient
    subject      "nested multipart"
    from         "test@example.com"
    content_type "multipart/mixed"
    part :content_type => "text/plain", :body => "hullo"
    attachment :content_type => "application/octet-stream", :data => "test abcdefghijklmnopqstuvwxyz"
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
    headers["return-path"] = "another@somewhere.test"
    body         "testing"
  end

  def subject_with_i18n(recipient)
    recipients recipient
    from       "system@loudthinking.com"
    body       "testing"
  end

  class << self
    attr_accessor :received_body
  end

  def receive(mail)
    self.class.received_body = mail.body
  end
end

class ActionMailerTest < Test::Unit::TestCase

  def encode( text, charset="UTF-8" )
    Mail::Encodings.q_value_encode( text, charset )
  end

  def new_mail( charset="UTF-8" )
    mail = Mail.new
    mail.charset = charset
    mail.mime_version = "1.0"
    mail
  end

  def setup
    set_delivery_method :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.deliveries.clear
    ActiveSupport::Deprecation.silenced = true

    @recipient = 'test@localhost'

    TestMailer.delivery_method = :test
  end

  def teardown
    ActiveSupport::Deprecation.silenced = false
    restore_delivery_method
  end

  def test_nested_parts
    created = nil
    assert_nothing_raised { created = TestMailer.nested_multipart(@recipient)}
    assert_equal 2, created.parts.size
    assert_equal 2, created.parts.first.parts.size

    assert_equal "multipart/mixed", created.mime_type
    assert_equal "multipart/alternative", created.parts[0].mime_type
    assert_equal "bar", created.parts[0].header['foo'].to_s
    assert_not_nil created.parts[0].charset
    assert_equal "text/plain", created.parts[0].parts[0].mime_type
    assert_equal "text/html", created.parts[0].parts[1].mime_type
    assert_equal "application/octet-stream", created.parts[1].mime_type

  end

  def test_nested_parts_with_body
    created = nil
    TestMailer.nested_multipart_with_body(@recipient)
    assert_nothing_raised { created = TestMailer.nested_multipart_with_body(@recipient)}

    assert_equal 1,created.parts.size
    assert_equal 2,created.parts.first.parts.size

    assert_equal "multipart/mixed", created.mime_type
    assert_equal "multipart/alternative", created.parts.first.mime_type
    assert_equal "text/plain", created.parts.first.parts.first.mime_type
    assert_equal "Nothing to see here.", created.parts.first.parts.first.body.to_s
    assert_equal "text/html", created.parts.first.parts.second.mime_type
    assert_equal "<b>test</b> HTML<br/>", created.parts.first.parts.second.body.to_s
  end

  def test_attachment_with_custom_header
    created = nil
    assert_nothing_raised { created = TestMailer.attachment_with_custom_header(@recipient) }
    assert created.parts.any? { |p| p.header['content-id'].to_s == "<test@test.com>" }
  end

  def test_signed_up
    TestMailer.delivery_method = :test

    Time.stubs(:now => Time.now)

    expected = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there,\n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.now

    created = nil
    assert_nothing_raised { created = TestMailer.signed_up(@recipient) }
    assert_not_nil created

    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'

    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.signed_up(@recipient).deliver }

    delivered = ActionMailer::Base.deliveries.first
    assert_not_nil delivered

    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_custom_template
    expected         = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there,\n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.custom_template(@recipient) }
    assert_not_nil created
    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'
    assert_equal expected.encoded, created.encoded
  end

  def test_custom_templating_extension
    assert ActionView::Template.template_handler_extensions.include?("haml"), "haml extension was not registered"

    # N.b., custom_templating_extension.text.plain.haml is expected to be in fixtures/test_mailer directory
    expected         = new_mail
    expected.to      = @recipient
    expected.subject = "[Signed up] Welcome #{@recipient}"
    expected.body    = "Hello there, \n\nMr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    # Now that the template is registered, there should be one part. The text/plain part.
    created = nil
    assert_nothing_raised { created = TestMailer.custom_templating_extension(@recipient) }
    assert_not_nil created
    assert_equal 2, created.parts.length
    assert_equal 'text/plain', created.parts[0].mime_type
    assert_equal 'text/html', created.parts[1].mime_type
  end

  def test_cancelled_account
    expected         = new_mail
    expected.to      = @recipient
    expected.subject = "[Cancelled] Goodbye #{@recipient}"
    expected.body    = "Goodbye, Mr. #{@recipient}"
    expected.from    = "system@loudthinking.com"
    expected.date    = Time.local(2004, 12, 12)

    created = nil
    assert_nothing_raised { created = TestMailer.cancelled_account(@recipient) }
    assert_not_nil created
    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised { TestMailer.cancelled_account(@recipient).deliver }
    assert_not_nil ActionMailer::Base.deliveries.first
    delivered = ActionMailer::Base.deliveries.first
    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_cc_bcc
    expected         = new_mail
    expected.to      = @recipient
    expected.subject = "testing bcc/cc"
    expected.body    = "Nothing to see here."
    expected.from    = "system@loudthinking.com"
    expected.cc      = "nobody@loudthinking.com"
    expected.bcc     = "root@loudthinking.com"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.cc_bcc @recipient
    end
    assert_not_nil created
    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'
    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.cc_bcc(@recipient).deliver
    end

    assert_not_nil ActionMailer::Base.deliveries.first
    delivered = ActionMailer::Base.deliveries.first
    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_from_without_name_for_smtp
    TestMailer.delivery_method = :smtp
    TestMailer.from_without_name.deliver

    mail = MockSMTP.deliveries.first
    assert_not_nil mail
    mail, from, to = mail

    assert_equal ['root@loudthinking.com'], to
    assert_equal 'system@loudthinking.com', from
  end

  def test_from_with_name_for_smtp
    TestMailer.delivery_method = :smtp
    TestMailer.from_with_name.deliver

    mail = MockSMTP.deliveries.first
    assert_not_nil mail
    mail, from, to = mail

    assert_equal ['root@loudthinking.com'], to
    assert_equal 'system@loudthinking.com', from
  end

  def test_reply_to
    TestMailer.delivery_method = :test

    expected = new_mail

    expected.to       = @recipient
    expected.subject  = "testing reply_to"
    expected.body     = "Nothing to see here."
    expected.from     = "system@loudthinking.com"
    expected.reply_to = "atraver@gmail.com"
    expected.date     = Time.local 2008, 5, 23

    created = nil
    assert_nothing_raised do
      created = TestMailer.different_reply_to @recipient
    end
    assert_not_nil created

    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'

    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.different_reply_to(@recipient).deliver
    end

    delivered = ActionMailer::Base.deliveries.first
    assert_not_nil delivered

    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_iso_charset
    TestMailer.delivery_method = :test
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
      created = TestMailer.iso_charset @recipient
    end
    assert_not_nil created

    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'

    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.iso_charset(@recipient).deliver
    end

    delivered = ActionMailer::Base.deliveries.first
    assert_not_nil delivered

    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_unencoded_subject
    TestMailer.delivery_method = :test
    expected         = new_mail
    expected.to      = @recipient
    expected.subject = "testing unencoded subject"
    expected.body    = "Nothing to see here."
    expected.from    = "system@loudthinking.com"
    expected.cc      = "nobody@loudthinking.com"
    expected.bcc     = "root@loudthinking.com"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.unencoded_subject @recipient
    end
    assert_not_nil created

    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'

    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.unencoded_subject(@recipient).deliver
    end

    delivered = ActionMailer::Base.deliveries.first
    assert_not_nil delivered

    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_deliveries_array
    assert_not_nil ActionMailer::Base.deliveries
    assert_equal 0, ActionMailer::Base.deliveries.size
    TestMailer.signed_up(@recipient).deliver
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not_nil ActionMailer::Base.deliveries.first
  end

  def test_perform_deliveries_flag
    ActionMailer::Base.perform_deliveries = false
    TestMailer.signed_up(@recipient).deliver
    assert_equal 0, ActionMailer::Base.deliveries.size
    ActionMailer::Base.perform_deliveries = true
    TestMailer.signed_up(@recipient).deliver
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_doesnt_raise_errors_when_raise_delivery_errors_is_false
    ActionMailer::Base.raise_delivery_errors = false
    Mail::TestMailer.any_instance.expects(:deliver!).raises(Exception)
    assert_nothing_raised { TestMailer.signed_up(@recipient).deliver }
  end

  def test_performs_delivery_via_sendmail
    IO.expects(:popen).once.with('/usr/sbin/sendmail -i -t -f "system@loudthinking.com" test@localhost', 'w+')
    TestMailer.delivery_method = :sendmail
    TestMailer.signed_up(@recipient).deliver
  end

  def test_unquote_quoted_printable_subject
    msg = <<EOF
From: me@example.com
Subject: =?UTF-8?Q?testing_testing_=D6=A4?=
Content-Type: text/plain; charset=iso-8859-1

The body
EOF
    mail = Mail.new(msg)
    assert_equal "testing testing \326\244", mail.subject
    assert_equal "Subject: =?UTF-8?Q?testing_testing_=D6=A4?=\r\n", mail[:subject].encoded
  end

  def test_unquote_7bit_subject
    msg = <<EOF
From: me@example.com
Subject: this == working?
Content-Type: text/plain; charset=iso-8859-1

The body
EOF
    mail = Mail.new(msg)
    assert_equal "this == working?", mail.subject
    assert_equal "Subject: this == working?\r\n", mail[:subject].encoded
  end

  def test_unquote_7bit_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 7bit

The=3Dbody
EOF
    mail = Mail.new(msg)
    assert_equal "The=3Dbody", mail.body.to_s.strip
    assert_equal "The=3Dbody", mail.body.encoded.strip
  end

  def test_unquote_quoted_printable_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: quoted-printable

The=3Dbody
EOF
    mail = Mail.new(msg)
    assert_equal "The=body", mail.body.to_s.strip
    assert_equal "The=3Dbody=", mail.body.encoded.strip
  end

  def test_unquote_base64_body
    msg = <<EOF
From: me@example.com
Subject: subject
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: base64

VGhlIGJvZHk=
EOF
    mail = Mail.new(msg)
    assert_equal "The body", mail.body.to_s.strip
    assert_equal "VGhlIGJvZHk=", mail.body.encoded.strip
  end

  def test_extended_headers
    @recipient = "Grytøyr <test@localhost>"

    expected = new_mail "iso-8859-1"
    expected.to      = @recipient
    expected.subject = "testing extended headers"
    expected.body    = "Nothing to see here."
    expected.from    = "Grytøyr <stian1@example.net>"
    expected.cc      = "Grytøyr <stian2@example.net>"
    expected.bcc     = "Grytøyr <stian3@example.net>"
    expected.date    = Time.local 2004, 12, 12

    created = nil
    assert_nothing_raised do
      created = TestMailer.extended_headers @recipient
    end

    assert_not_nil created
    expected.message_id = '<123@456>'
    created.message_id = '<123@456>'

    assert_equal expected.encoded, created.encoded

    assert_nothing_raised do
      TestMailer.extended_headers(@recipient).deliver
    end

    delivered = ActionMailer::Base.deliveries.first
    assert_not_nil delivered

    expected.message_id = '<123@456>'
    delivered.message_id = '<123@456>'

    assert_equal expected.encoded, delivered.encoded
  end

  def test_utf8_body_is_not_quoted
    @recipient = "Foo áëô îü <extended@example.net>"
    expected = new_mail "UTF-8"
    expected.to      = @recipient
    expected.subject = "testing UTF-8 body"
    expected.body    = "åœö blah"
    expected.from    = @recipient
    expected.cc      = @recipient
    expected.bcc     = @recipient
    expected.date    = Time.local 2004, 12, 12

    created = TestMailer.utf8_body @recipient
    assert_match(/åœö blah/, created.decoded)
  end

  def test_multiple_utf8_recipients
    @recipient = ["\"Foo áëô îü\" <extended@example.net>", "\"Example Recipient\" <me@example.com>"]
    expected = new_mail "UTF-8"
    expected.to      = @recipient
    expected.subject = "testing UTF-8 body"
    expected.body    = "åœö blah"
    expected.from    = @recipient.first
    expected.cc      = @recipient
    expected.bcc     = @recipient
    expected.date    = Time.local 2004, 12, 12

    created = TestMailer.utf8_body @recipient
    from_regexp = Regexp.escape('From: Foo =?UTF-8?B?w6HDq8O0?= =?UTF-8?B?IMOuw7w=?=')
    assert_match(/#{from_regexp}/m, created.encoded)

    to_regexp   = Regexp.escape("To: =?UTF-8?B?Rm9vIMOhw6vDtCDDrsO8?= <extended@example.net>")
    assert_match(/#{to_regexp}/m, created.encoded)
  end

  def test_receive_decodes_base64_encoded_mail
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email")
    TestMailer.receive(fixture)
    assert_match(/Jamis/, TestMailer.received_body.to_s)
  end

  def test_receive_attachments
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email2")
    mail = Mail.new(fixture)
    attachment = mail.attachments.last
    assert_equal "smime.p7s", attachment.filename
    assert_equal "application/pkcs7-signature", mail.parts.last.mime_type
  end

  def test_decode_attachment_without_charset
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email3")
    mail = Mail.new(fixture)
    attachment = mail.attachments.last
    assert_equal 1026, attachment.read.length
  end

  def test_attachment_using_content_location
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email12")
    mail = Mail.new(fixture)
    assert_equal 1, mail.attachments.length
    assert_equal "Photo25.jpg", mail.attachments.first.filename
  end

  def test_attachment_with_text_type
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email13")
    mail = Mail.new(fixture)
    assert mail.has_attachments?
    assert_equal 1, mail.attachments.length
    assert_equal "hello.rb", mail.attachments.first.filename
  end

  def test_decode_part_without_content_type
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email4")
    mail = Mail.new(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_decode_message_without_content_type
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email5")
    mail = Mail.new(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_decode_message_with_incorrect_charset
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email6")
    mail = Mail.new(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_multipart_with_mime_version
    mail = TestMailer.multipart_with_mime_version(@recipient)
    assert_equal "1.1", mail.mime_version
  end

  def test_multipart_with_utf8_subject
    mail = TestMailer.multipart_with_utf8_subject(@recipient)
    regex = Regexp.escape('Subject: =?UTF-8?Q?Foo_=C3=A1=C3=AB=C3=B4_=C3=AE=C3=BC?=')
    assert_match(/#{regex}/, mail.encoded)
    string = "Foo áëô îü"
    assert_match(string, mail.subject)
  end

  def test_implicitly_multipart_with_utf8
    mail = TestMailer.implicitly_multipart_with_utf8
    regex = Regexp.escape('Subject: =?UTF-8?Q?Foo_=C3=A1=C3=AB=C3=B4_=C3=AE=C3=BC?=')
    assert_match(/#{regex}/, mail.encoded)
    string = "Foo áëô îü"
    assert_match(string, mail.subject)
  end

  def test_explicitly_multipart_messages
    mail = TestMailer.explicitly_multipart_example(@recipient)
    assert_equal 3, mail.parts.length
    assert_equal 'multipart/mixed', mail.mime_type
    assert_equal "text/plain", mail.parts[0].mime_type

    assert_equal "text/html", mail.parts[1].mime_type
    assert_equal "iso-8859-1", mail.parts[1].charset

    assert_equal "image/jpeg", mail.parts[2].mime_type

    assert_equal "attachment", mail.parts[2][:content_disposition].disposition_type
    assert_equal "foo.jpg", mail.parts[2][:content_disposition].filename
    assert_equal "foo.jpg", mail.parts[2][:content_type].filename
    assert_nil mail.parts[2].charset
  end

  def test_explicitly_multipart_with_content_type
    mail = TestMailer.explicitly_multipart_example(@recipient, "multipart/alternative")
    assert_equal 3, mail.parts.length
    assert_equal "multipart/alternative", mail.mime_type
  end

  def test_explicitly_multipart_with_invalid_content_type
    mail = TestMailer.explicitly_multipart_example(@recipient, "text/xml")
    assert_equal 3, mail.parts.length
    assert_equal 'multipart/mixed', mail.mime_type
  end

  def test_implicitly_multipart_messages
    assert ActionView::Template.template_handler_extensions.include?("bak"), "bak extension was not registered"

    mail = TestMailer.implicitly_multipart_example(@recipient)
    assert_equal 3, mail.parts.length
    assert_equal "1.0", mail.mime_version.to_s
    assert_equal "multipart/alternative", mail.mime_type
    assert_equal "text/plain", mail.parts[0].mime_type
    assert_equal "UTF-8", mail.parts[0].charset
    assert_equal "text/html", mail.parts[1].mime_type
    assert_equal "UTF-8", mail.parts[1].charset
    assert_equal "application/x-yaml", mail.parts[2].mime_type
    assert_equal "UTF-8", mail.parts[2].charset
  end

  def test_implicitly_multipart_messages_with_custom_order
    assert ActionView::Template.template_handler_extensions.include?("bak"), "bak extension was not registered"

    mail = TestMailer.implicitly_multipart_example(@recipient, nil, ["application/x-yaml", "text/plain"])
    assert_equal 3, mail.parts.length
    assert_equal "application/x-yaml", mail.parts[0].mime_type
    assert_equal "text/plain", mail.parts[1].mime_type
    assert_equal "text/html", mail.parts[2].mime_type
  end

  def test_implicitly_multipart_messages_with_charset
    mail = TestMailer.implicitly_multipart_example(@recipient, 'iso-8859-1')

    assert_equal "multipart/alternative", mail.header['content-type'].content_type

    assert_equal 'iso-8859-1', mail.parts[0].content_type_parameters[:charset]
    assert_equal 'iso-8859-1', mail.parts[1].content_type_parameters[:charset]
    assert_equal 'iso-8859-1', mail.parts[2].content_type_parameters[:charset]
  end

  def test_html_mail
    mail = TestMailer.html_mail(@recipient)
    assert_equal "text/html", mail.mime_type
  end

  def test_html_mail_with_underscores
    mail = TestMailer.html_mail_with_underscores(@recipient)
    assert_equal %{<a href="http://google.com" target="_blank">_Google</a>}, mail.body.to_s
  end

  def test_various_newlines
    mail = TestMailer.various_newlines(@recipient)
    assert_equal("line #1\nline #2\nline #3\nline #4\n\n" +
                 "line #5\n\nline#6\n\nline #7", mail.body.to_s)
  end

  def test_various_newlines_multipart
    mail = TestMailer.various_newlines_multipart(@recipient)
    assert_equal "line #1\nline #2\nline #3\nline #4\n\n", mail.parts[0].body.to_s
    assert_equal "<p>line #1</p>\n<p>line #2</p>\n<p>line #3</p>\n<p>line #4</p>\n\n", mail.parts[1].body.to_s
    assert_equal "line #1\r\nline #2\r\nline #3\r\nline #4\r\n\r\n", mail.parts[0].body.encoded
    assert_equal "<p>line #1</p>\r\n<p>line #2</p>\r\n<p>line #3</p>\r\n<p>line #4</p>\r\n\r\n", mail.parts[1].body.encoded
  end

  def test_headers_removed_on_smtp_delivery
    TestMailer.delivery_method = :smtp
    TestMailer.cc_bcc(@recipient).deliver
    assert MockSMTP.deliveries[0][2].include?("root@loudthinking.com")
    assert MockSMTP.deliveries[0][2].include?("nobody@loudthinking.com")
    assert MockSMTP.deliveries[0][2].include?(@recipient)
    assert_match %r{^Cc: nobody@loudthinking.com}, MockSMTP.deliveries[0][0]
    assert_match %r{^To: #{@recipient}}, MockSMTP.deliveries[0][0]
    assert_no_match %r{^Bcc: root@loudthinking.com}, MockSMTP.deliveries[0][0]
  end

   def test_file_delivery_should_create_a_file
     TestMailer.delivery_method = :file
     tmp_location = TestMailer.file_settings[:location]

     TestMailer.cc_bcc(@recipient).deliver
     assert File.exists?(tmp_location)
     assert File.directory?(tmp_location)
     assert File.exists?(File.join(tmp_location, @recipient))
     assert File.exists?(File.join(tmp_location, 'nobody@loudthinking.com'))
     assert File.exists?(File.join(tmp_location, 'root@loudthinking.com'))
   end

  def test_recursive_multipart_processing
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email7")
    mail = Mail.new(fixture)
    assert_equal(2, mail.parts.length)
    assert_equal(4, mail.parts.first.parts.length)
    assert_equal("This is the first part.", mail.parts.first.parts.first.body.to_s)
    assert_equal("test.rb", mail.parts.first.parts.second.filename)
    assert_equal("flowed", mail.parts.first.parts.fourth.content_type_parameters[:format])
    assert_equal('smime.p7s', mail.parts.second.filename)
  end

  def test_decode_encoded_attachment_filename
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email8")
    mail = Mail.new(fixture)
    attachment = mail.attachments.last

    expected = "01 Quien Te Dij\212at. Pitbull.mp3"

    if expected.respond_to?(:force_encoding)
      result = attachment.filename.dup
      expected.force_encoding(Encoding::ASCII_8BIT)
      result.force_encoding(Encoding::ASCII_8BIT)
      assert_equal expected, result
    else
      assert_equal expected, attachment.filename
    end
  end

  def test_decode_message_with_unknown_charset
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/raw_email10")
    mail = Mail.new(fixture)
    assert_nothing_raised { mail.body }
  end

  def test_empty_header_values_omitted
    result = TestMailer.unnamed_attachment(@recipient).encoded
    assert_match %r{Content-Type: application/octet-stream}, result
    assert_match %r{Content-Disposition: attachment}, result
  end

  def test_headers_with_nonalpha_chars
    mail = TestMailer.headers_with_nonalpha_chars(@recipient)
    assert !mail.from_addrs.empty?
    assert !mail.cc_addrs.empty?
    assert !mail.bcc_addrs.empty?
    assert_match(/:/, mail[:from].decoded)
    assert_match(/:/, mail[:cc].decoded)
    assert_match(/:/, mail[:bcc].decoded)
  end

  def test_with_mail_object_deliver
    TestMailer.delivery_method = :test
    mail = TestMailer.headers_with_nonalpha_chars(@recipient)
    assert_nothing_raised { mail.deliver }
    assert_equal 1, TestMailer.deliveries.length
  end

  def test_multipart_with_template_path_with_dots
    mail = FunkyPathMailer.multipart_with_template_path_with_dots(@recipient)
    assert_equal 2, mail.parts.length
    assert_equal "text/plain", mail.parts[0].mime_type
    assert_equal "text/html", mail.parts[1].mime_type
    assert_equal "UTF-8", mail.parts[1].charset
  end

  def test_custom_content_type_attributes
    mail = TestMailer.custom_content_type_attributes
    assert_match %r{format=flowed}, mail.content_type
    assert_match %r{charset=UTF-8}, mail.content_type
  end

  def test_return_path_with_create
    mail = TestMailer.return_path
    assert_equal "another@somewhere.test", mail.return_path
  end

  def test_return_path_with_deliver
    TestMailer.delivery_method = :smtp
    TestMailer.return_path.deliver
    assert_match %r{^Return-Path: <another@somewhere.test>}, MockSMTP.deliveries[0][0]
    assert_equal "another@somewhere.test", MockSMTP.deliveries[0][1].to_s
  end

  def test_starttls_is_enabled_if_supported
    TestMailer.smtp_settings.merge!(:enable_starttls_auto => true)
    MockSMTP.any_instance.expects(:respond_to?).with(:enable_starttls_auto).returns(true)
    MockSMTP.any_instance.expects(:enable_starttls_auto)
    TestMailer.delivery_method = :smtp
    TestMailer.signed_up(@recipient).deliver
  end

  def test_starttls_is_disabled_if_not_supported
    TestMailer.smtp_settings.merge!(:enable_starttls_auto => true)
    MockSMTP.any_instance.expects(:respond_to?).with(:enable_starttls_auto).returns(false)
    MockSMTP.any_instance.expects(:enable_starttls_auto).never
    TestMailer.delivery_method = :smtp
    TestMailer.signed_up(@recipient).deliver
  end

  def test_starttls_is_not_enabled
    TestMailer.smtp_settings.merge!(:enable_starttls_auto => false)
    MockSMTP.any_instance.expects(:respond_to?).never
    TestMailer.delivery_method = :smtp
    TestMailer.signed_up(@recipient).deliver
  ensure
    TestMailer.smtp_settings.merge!(:enable_starttls_auto => true)
  end
end
