# frozen_string_literal: true

require_relative 'abstract_unit'
require 'active_support/inflector/transliterate'

class TransliterateTest < ActiveSupport::TestCase
  def test_transliterate_should_not_change_ascii_chars
    (0..127).each do |byte|
      char = [byte].pack('U')
      assert_equal char, ActiveSupport::Inflector.transliterate(char)
    end
  end

  def test_transliterate_should_approximate_ascii
    # create string with range of Unicode's western characters with
    # diacritics, excluding the division and multiplication signs which for
    # some reason or other are floating in the middle of all the letters.
    string = (0xC0..0x17E).to_a.reject { |c| [0xD7, 0xF7].include?(c) }.pack('U*')
    string.each_char do |char|
      assert_match %r{^[a-zA-Z']*$}, ActiveSupport::Inflector.transliterate(char)
    end
  end

  def test_transliterate_should_work_with_custom_i18n_rules_and_uncomposed_utf8
    char = [117, 776].pack('U*') # "ü" as ASCII "u" plus COMBINING DIAERESIS
    I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { 'ü' => 'ue' } } })
    default_locale, I18n.locale = I18n.locale, :de
    assert_equal 'ue', ActiveSupport::Inflector.transliterate(char)
  ensure
    I18n.locale = default_locale
  end

  def test_transliterate_respects_the_locale_argument
    char = [117, 776].pack('U*') # "ü" as ASCII "u" plus COMBINING DIAERESIS
    I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { 'ü' => 'ue' } } })
    assert_equal 'ue', ActiveSupport::Inflector.transliterate(char, locale: :de)
  end

  def test_transliterate_should_allow_a_custom_replacement_char
    assert_equal 'a*b', ActiveSupport::Inflector.transliterate('a索b', '*')
  end

  def test_transliterate_handles_empty_string
    assert_equal '', ActiveSupport::Inflector.transliterate('')
  end

  def test_transliterate_handles_nil
    exception = assert_raises ArgumentError do
      ActiveSupport::Inflector.transliterate(nil)
    end
    assert_equal 'Can only transliterate strings. Received NilClass', exception.message
  end

  def test_transliterate_handles_unknown_object
    exception = assert_raises ArgumentError do
      ActiveSupport::Inflector.transliterate(Object.new)
    end
    assert_equal 'Can only transliterate strings. Received Object', exception.message
  end

  def test_transliterate_handles_strings_with_valid_utf8_encodings
    string = String.new('A', encoding: Encoding::UTF_8).freeze
    assert_equal 'A', ActiveSupport::Inflector.transliterate(string)
  end

  def test_transliterate_handles_strings_with_valid_us_ascii_encodings
    string = String.new('A', encoding: Encoding::US_ASCII).freeze
    transcoded = ActiveSupport::Inflector.transliterate(string)
    assert_equal 'A', transcoded
    assert_equal Encoding::US_ASCII, transcoded.encoding
  end

  def test_transliterate_handles_strings_with_valid_gb18030_encodings
    string = String.new('A', encoding: Encoding::GB18030).freeze
    transcoded = ActiveSupport::Inflector.transliterate(string)
    assert_equal 'A', transcoded
    assert_equal Encoding::GB18030, transcoded.encoding
  end

  def test_transliterate_handles_strings_with_incompatible_encodings
    incompatible_encodings = Encoding.list - [
      Encoding::UTF_8,
      Encoding::US_ASCII,
      Encoding::GB18030
    ]
    incompatible_encodings.each do |encoding|
      string = String.new('', encoding: encoding).freeze
      exception = assert_raises ArgumentError do
        ActiveSupport::Inflector.transliterate(string)
      end
      assert_equal "Cannot transliterate strings with #{encoding} encoding", exception.message
    end
  end

  def test_transliterate_handles_strings_with_invalid_utf8_bytes
    string = String.new("\255", encoding: Encoding::UTF_8).freeze
    assert_equal '?', ActiveSupport::Inflector.transliterate(string)
  end

  def test_transliterate_handles_strings_with_invalid_us_ascii_bytes
    string = String.new("\255", encoding: Encoding::US_ASCII).freeze
    assert_equal '?', ActiveSupport::Inflector.transliterate(string)
  end

  def test_transliterate_handles_strings_with_invalid_gb18030_bytes
    string = String.new("\255", encoding: Encoding::GB18030).freeze
    assert_equal '?', ActiveSupport::Inflector.transliterate(string)
  end
end
