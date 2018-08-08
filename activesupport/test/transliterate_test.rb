# frozen_string_literal: true

require "abstract_unit"
require "active_support/inflector/transliterate"

class TransliterateTest < ActiveSupport::TestCase
  def test_transliterate_should_not_change_ascii_chars
    (0..127).each do |byte|
      char = [byte].pack("U")
      assert_equal char, ActiveSupport::Inflector.transliterate(char)
    end
  end

  def test_transliterate_should_approximate_ascii
    # create string with range of Unicode's western characters with
    # diacritics, excluding the division and multiplication signs which for
    # some reason or other are floating in the middle of all the letters.
    string = (0xC0..0x17E).to_a.reject { |c| [0xD7, 0xF7].include?(c) }.pack("U*")
    string.each_char do |char|
      assert_match %r{^[a-zA-Z']*$}, ActiveSupport::Inflector.transliterate(char)
    end
  end

  def test_transliterate_should_work_with_custom_i18n_rules_and_uncomposed_utf8
    char = [117, 776].pack("U*") # "ü" as ASCII "u" plus COMBINING DIAERESIS
    I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { "ü" => "ue" } } })
    default_locale, I18n.locale = I18n.locale, :de
    assert_equal "ue", ActiveSupport::Inflector.transliterate(char)
  ensure
    I18n.locale = default_locale
  end

  def test_transliterate_should_allow_a_custom_replacement_char
    assert_equal "a*b", ActiveSupport::Inflector.transliterate("a索b", "*")
  end

  def test_transliterate_handles_empty_string
    assert_equal "", ActiveSupport::Inflector.transliterate("")
  end

  def test_transliterate_handles_nil
    exception = assert_raises ArgumentError do
      ActiveSupport::Inflector.transliterate(nil)
    end
    assert_equal "Can only transliterate strings. Received NilClass", exception.message
  end

  def test_transliterate_handles_unknown_object
    exception = assert_raises ArgumentError do
      ActiveSupport::Inflector.transliterate(Object.new)
    end
    assert_equal "Can only transliterate strings. Received Object", exception.message
  end
end
