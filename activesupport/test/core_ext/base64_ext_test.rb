require 'abstract_unit'

class Base64Test < Test::Unit::TestCase
  def test_no_newline_in_encoded_value
    assert_match(/\n/,    ActiveSupport::Base64.encode64("oneverylongstringthatwouldnormallybesplitupbynewlinesbytheregularbase64"))
    assert_no_match(/\n/, ActiveSupport::Base64.encode64s("oneverylongstringthatwouldnormallybesplitupbynewlinesbytheregularbase64"))
  end
end
