# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendTransliterator < Test::Unit::TestCase

  def setup
    I18n.backend = I18n::Backend::Simple.new
    @proc = lambda { |n| n.upcase }
    @hash = { :"ü" => "ue", :"ö" => "oe" }
    @transliterator = I18n::Backend::Transliterator.get
  end

  test "transliteration rule can be a proc" do
    store_translations(:xx, :i18n => {:transliterate => {:rule => @proc}})
    assert_equal "HELLO", I18n.backend.transliterate(:xx, "hello")
  end

  test "transliteration rule can be a hash" do
    store_translations(:xx, :i18n => {:transliterate => {:rule => @hash}})
    assert_equal "ue", I18n.backend.transliterate(:xx, "ü")
  end

  test "transliteration rule must be a proc or hash" do
    store_translations(:xx, :i18n => {:transliterate => {:rule => ""}})
    assert_raise I18n::ArgumentError do
      I18n.backend.transliterate(:xx, "ü")
    end
  end

  test "transliterator defaults to latin => ascii when no rule is given" do
    assert_equal "AEroskobing", I18n.backend.transliterate(:xx, "Ærøskøbing")
  end

  test "default transliterator should not modify ascii characters" do
    (0..127).each do |byte|
      char = [byte].pack("U")
      assert_equal char, @transliterator.transliterate(char)
    end
  end

  test "default transliterator correctly transliterates latin characters" do
    # create string with range of Unicode's western characters with
    # diacritics, excluding the division and multiplication signs which for
    # some reason or other are floating in the middle of all the letters.
    string = (0xC0..0x17E).to_a.reject {|c| [0xD7, 0xF7].include? c}.pack("U*")
    string.split(//) do |char|
      assert_match %r{^[a-zA-Z']*$}, @transliterator.transliterate(string)
    end
  end

  test "should replace non-ASCII chars not in map with a replacement char" do
    assert_equal "abc?", @transliterator.transliterate("abcſ")
  end

  test "can replace non-ASCII chars not in map with a custom replacement string" do
    assert_equal "abc#", @transliterator.transliterate("abcſ", "#")
  end

  if RUBY_VERSION >= "1.9"
    test "default transliterator raises errors for invalid UTF-8" do
      assert_raise ArgumentError do
        @transliterator.transliterate("a\x92b")
      end
    end
  end

  test "I18n.transliterate should transliterate using a default transliterator" do
    assert_equal "aeo", I18n.transliterate("áèö")
  end

  test "I18n.transliterate should transliterate using a locale" do
    store_translations(:xx, :i18n => {:transliterate => {:rule => @hash}})
    assert_equal "ue", I18n.transliterate("ü", :locale => :xx)
  end

  test "default transliterator fails with custom rules with uncomposed input" do
    char = [117, 776].pack("U*") # "ü" as ASCII "u" plus COMBINING DIAERESIS
    transliterator = I18n::Backend::Transliterator.get(@hash)
    assert_not_equal "ue", transliterator.transliterate(char)
  end

end
