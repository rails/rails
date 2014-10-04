require 'active_record_unit'

class DebugHelperTest < ActionView::TestCase
  def test_debug
    company = Company.new(name: "firebase")
    assert_match "name: firebase", debug(company)
  end
end
