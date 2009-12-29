require 'abstract_unit'

class MailTest < Test::Unit::TestCase
  def test_body
    m = Mail.new
    expected = 'something_with_underscores'
    m.content_transfer_encoding = 'quoted-printable'
    quoted_body = [expected].pack('*M')
    m.body = quoted_body
    assert_equal "something_with_underscores=\r\n", m.body.encoded
    # CHANGED: body returns object, not string, Changed m.body to m.body.to_s
    assert_equal expected, m.body.to_s
  end

  def test_nested_attachments_are_recognized_correctly
    fixture = File.read("#{File.dirname(__FILE__)}/fixtures/raw_email_with_nested_attachment")
    mail = Mail.new(fixture)
    assert_equal 2, mail.attachments.length
    assert_equal "image/png", mail.attachments.first.mime_type
    assert_equal 1902, mail.attachments.first.decoded.length
    assert_equal "application/pkcs7-signature", mail.attachments.last.mime_type
  end
  
end
