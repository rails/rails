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

  BLANK = [ EmptyTrue.new, nil, false, "", "   ", "  \n\t  \r ", "　", "\u00a0", "  ", "　 ", "  ", [], {} ].freeze
  NOT   = [ EmptyFalse.new, Object.new, true, 0, 1, "a", " a", "a ", "\0", " \0", " a", "  a", [nil], { nil => 0 }, Time.now ].freeze

  def test_blank
    BLANK.each { |v| assert_equal true, v.blank?,  "#{v.inspect} should be blank" }
    NOT.each   { |v| assert_equal false, v.blank?, "#{v.inspect} should not be blank" }
  end

  def test_blank_with_bundled_string_encodings
    Encoding.list.reject(&:dummy?).each do |encoding|
      assert_predicate " ".encode(encoding), :blank?
      assert_predicate " \t\n".encode(encoding), :blank?
      assert_not_predicate "a".encode(encoding), :blank?
      assert_not_predicate " a".encode(encoding), :blank?
    end
  end

  def test_blank_with_encoding_specific_whitespace
    # KOI8-R puts its no-break space at 0x9A, outside the Unicode whitespace codepoints.
    assert_predicate "\x9a".b.force_encoding("KOI8-R"), :blank?
    assert_not_predicate "\x9a".b.force_encoding("ISO-8859-1"), :blank?
  end

  def test_blank_with_invalid_byte_sequence
    assert_raises(ArgumentError) { "\xff".blank? }
    assert_raises(ArgumentError) { "a\xff".blank? }
    assert_raises(ArgumentError) { " \xff".blank? }
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
