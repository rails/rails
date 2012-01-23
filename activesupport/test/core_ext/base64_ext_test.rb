require 'abstract_unit'

class Base64Test < Test::Unit::TestCase
  def test_no_newline_in_encoded_value
    ActiveSupport::Deprecation.silence do
      assert_match(/\n/,    ActiveSupport::Base64.encode64("oneverylongstringthatwouldnormallybesplitupbynewlinesbytheregularbase64"))
      assert_no_match(/\n/, ActiveSupport::Base64.encode64s("oneverylongstringthatwouldnormallybesplitupbynewlinesbytheregularbase64"))
    end
  end

  def test_encode_and_decode
    ActiveSupport::Deprecation.silence do
      string = "foobar"
      encoded_string = ActiveSupport::Base64.encode64(string)
      assert_equal "Zm9vYmFy\n", encoded_string
      assert_equal string, ActiveSupport::Base64.decode64(encoded_string)
    end
  end
end
