require 'abstract_unit'

class TmailCompatTest < ActiveSupport::TestCase
  def setup
    @silence = ActiveSupport::Deprecation.silenced
    ActiveSupport::Deprecation.silenced = false
  end

  def teardown
    ActiveSupport::Deprecation.silenced = @silence
  end

  def test_set_content_type_raises_deprecation_warning
    mail = Mail.new
    assert_deprecated do
      assert_nothing_raised do
        mail.set_content_type "text/plain"
      end
    end
    assert_equal mail.mime_type, "text/plain"
  end

  def test_transfer_encoding_raises_deprecation_warning
    mail = Mail.new
    assert_deprecated do
      assert_nothing_raised do
        mail.transfer_encoding "base64"
      end
    end
    assert_equal mail.content_transfer_encoding, "base64"
  end

  def test_transfer_encoding_setter_raises_deprecation_warning
    mail = Mail.new
    assert_deprecated do
      assert_nothing_raised do
        mail.transfer_encoding = "base64"
      end
    end
    assert_equal mail.content_transfer_encoding, "base64"
  end
end
