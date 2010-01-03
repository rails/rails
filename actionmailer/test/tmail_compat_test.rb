require 'abstract_unit'

class TmailCompatTest < Test::Unit::TestCase

  def test_set_content_type_raises_deprecation_warning
    mail = Mail.new
    STDERR.expects(:puts) # Deprecation warning
    assert_nothing_raised do
      mail.set_content_type "text/plain"
    end
    assert_equal mail.mime_type, "text/plain"
  end

  def test_transfer_encoding_raises_deprecation_warning
    mail = Mail.new
    STDERR.expects(:puts) # Deprecation warning
    assert_nothing_raised do
      mail.transfer_encoding "base64"
    end
    assert_equal mail.content_transfer_encoding, "base64"
  end
  
end
