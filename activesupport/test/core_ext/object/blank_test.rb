# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'active_support/core_ext/object/blank'

class BlankTest < ActiveSupport::TestCase
  class EmptyTrue
    def empty?
      0
    end
  end

  class EmptyFalse
    def empty?
      nil
    end
  end

  BLANK = [ EmptyTrue.new, nil, false, '', '   ', "  \n\t  \r ", '　', "\u00a0", [], {}, ' '.encode('UTF-16LE') ]
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, 'a', [nil], { nil => 0 }, Time.now, 'my value'.encode('UTF-16LE') ]

  def test_blank
    BLANK.each { |v| assert_equal true, v.blank?,  "#{v.inspect} should be blank" }
    NOT.each   { |v| assert_equal false, v.blank?, "#{v.inspect} should not be blank" }
  end

  def test_present
    BLANK.each { |v| assert_equal false, v.present?, "#{v.inspect} should not be present" }
    NOT.each   { |v| assert_equal true, v.present?,  "#{v.inspect} should be present" }
  end

  def test_presence
    BLANK.each { |v| assert_nil v.presence, "#{v.inspect}.presence should return nil" }
    NOT.each   { |v| assert_equal v,   v.presence, "#{v.inspect}.presence should return self" }
  end
end
