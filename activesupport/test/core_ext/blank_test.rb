# encoding: utf-8

require 'abstract_unit'
require 'active_support/core_ext/object/blank'

class BlankTest < ActiveSupport::TestCase
  BLANK = [ EmptyTrue.new, nil, false, '', '   ', "  \n\t  \r ", '　', [], {} ]
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, 'a', [nil], { nil => 0 } ]

  def test_blank
    BLANK.each { |v| assert v.blank?,  "#{v.inspect} should be blank" }
    NOT.each   { |v| assert !v.blank?, "#{v.inspect} should not be blank" }
  end

  def test_present
    BLANK.each { |v| assert !v.present?, "#{v.inspect} should not be present" }
    NOT.each   { |v| assert v.present?,  "#{v.inspect} should be present" }
  end

  def test_presence
    BLANK.each { |v| assert_equal nil, v.presence, "#{v.inspect}.presence should return nil" }
    NOT.each   { |v| assert_equal v,   v.presence, "#{v.inspect}.presence should return self" }
  end
end
