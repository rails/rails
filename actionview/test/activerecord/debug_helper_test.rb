# frozen_string_literal: true

require "active_record_unit"
require "nokogiri"

class DebugHelperTest < ActionView::TestCase
  def test_debug
    company = Company.new(name: "firebase")
    output = debug(company)
    assert_match "name: name", output
    assert_match "value_before_type_cast: firebase", output
    assert_match "active_record_yaml_version: 2", output
  end

  def test_debug_with_marshal_error
    obj = -> {}
    assert_match obj.inspect, Nokogiri.XML(debug(obj)).content
  end
end
