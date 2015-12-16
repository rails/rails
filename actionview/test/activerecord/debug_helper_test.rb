require 'active_record_unit'
require 'nokogiri'

class DebugHelperTest < ActionView::TestCase
  def test_debug
    company = Company.new(name: "firebase")
    assert_match "name: firebase", debug(company)
  end

  def test_debug_with_marshal_error
    obj = -> { }
    assert_match obj.inspect, Nokogiri.XML(debug(obj)).content
  end
end
