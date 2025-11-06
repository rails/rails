# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/blank"

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

  BLANK = [ EmptyTrue.new, nil, false, "", "   ", "  \n\t  \r ", "　", "\u00a0", [], {} ]
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, "a", [nil], { nil => 0 }, Time.now ]

  test "blank", each: BLANK do |value|
    assert_equal true, value.blank?
  end

  test "not blank", each: NOT do |value|
    assert_equal false, value.blank?
  end

  test "blank with bundled string encodings", each: Encoding.list.reject(&:dummy?) do |encoding|
    assert_predicate " ".encode(encoding), :blank?
    assert_not_predicate "a".encode(encoding), :blank?
  end

  test "present", each: NOT do |value|
    assert_equal true, value.present?
  end

  test "not present", each: BLANK do |value|
    assert_equal false, value.present?
  end

  test "presence is self", each: NOT do |value|
    assert_equal value, value.presence
  end

  test "presence is nil", each: BLANK do |value|
    assert_nil value.presence
  end
end
