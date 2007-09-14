require "#{File.dirname(__FILE__)}/abstract_unit"

class TMailMailTest < Test::Unit::TestCase
  def test_body
    m = TMail::Mail.new
    expected = 'something_with_underscores'
    m.encoding = 'quoted-printable'
    quoted_body = [expected].pack('*M')
    m.body = quoted_body
    assert_equal "something_with_underscores=\n", m.quoted_body
    assert_equal expected, m.body
  end

  def test_nested_attachments_are_recognized_correctly
    fixture = File.read("#{File.dirname(__FILE__)}/fixtures/raw_email_with_nested_attachment")
    mail = TMail::Mail.parse(fixture)
    assert_equal 2, mail.attachments.length
    assert_equal "image/png", mail.attachments.first.content_type
    assert_equal 1902, mail.attachments.first.length
    assert_equal "application/pkcs7-signature", mail.attachments.last.content_type
  end
end
