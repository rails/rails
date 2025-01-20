# frozen_string_literal: true

require "date"
require_relative "../abstract_unit"
require "timeout"
require_relative "../inflector_test_cases"
require_relative "../constantize_test_cases"

require "active_support/inflector"
require "active_support/core_ext/string"
require "active_support/time"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/string/indent"
require "active_support/core_ext/string/strip"
require_relative "../time_zone_test_helpers"
require "yaml"

class StringInflectionsTest < ActiveSupport::TestCase
  include InflectorTestCases
  include ConstantizeTestCases
  include TimeZoneTestHelpers

  def test_strip_heredoc_on_an_empty_string
    assert_equal "", "".strip_heredoc
  end

  def test_strip_heredoc_on_a_frozen_string
    assert_predicate "".strip_heredoc, :frozen?
  end

  def test_strip_heredoc_on_a_string_with_no_lines
    assert_equal "x", "x".strip_heredoc
    assert_equal "x", "    x".strip_heredoc
  end

  def test_strip_heredoc_on_a_heredoc_with_no_margin
    assert_equal "foo\nbar", "foo\nbar".strip_heredoc
    assert_equal "foo\n  bar", "foo\n  bar".strip_heredoc
  end

  def test_strip_heredoc_on_a_regular_indented_heredoc
    assert_equal "foo\n  bar\nbaz\n", <<-EOS.strip_heredoc
      foo
        bar
      baz
    EOS
  end

  def test_strip_heredoc_on_a_regular_indented_heredoc_with_blank_lines
    assert_equal "foo\n  bar\n\nbaz\n", <<-EOS.strip_heredoc
      foo
        bar

      baz
    EOS
  end

  def test_pluralize
    SingularToPlural.each do |singular, plural|
      assert_equal(plural, singular.pluralize)
    end

    assert_equal("plurals", "plurals".pluralize)

    assert_equal("blargles", "blargle".pluralize(0))
    assert_equal("blargle", "blargle".pluralize(1))
    assert_equal("blargles", "blargle".pluralize(2))
  end

  test "pluralize with count = 1 still returns new string" do
    name = "Kuldeep"
    assert_not_same name.pluralize(1), name
  end

  def test_singularize
    SingularToPlural.each do |singular, plural|
      assert_equal(singular, plural.singularize)
    end
  end

  def test_titleize
    MixtureToTitleCase.each do |before, titleized|
      assert_equal(titleized, before.titleize)
    end
  end

  def test_titleize_with_keep_id_suffix
    MixtureToTitleCaseWithKeepIdSuffix.each do |before, titleized|
      assert_equal(titleized, before.titleize(keep_id_suffix: true))
    end
  end

  def test_downcase_first
    assert_equal "try again", "Try again".downcase_first
  end

  def test_downcase_first_with_one_char
    assert_equal "t", "T".downcase_first
  end

  def test_downcase_first_with_empty_string
    assert_equal "", "".downcase_first
    assert_not_predicate "".downcase_first, :frozen?
  end

  def test_upcase_first
    assert_equal "What a Lovely Day", "what a Lovely Day".upcase_first
  end

  def test_upcase_first_with_one_char
    assert_equal "W", "w".upcase_first
  end

  def test_upcase_first_with_empty_string
    assert_equal "", "".upcase_first
    assert_not_predicate "".upcase_first, :frozen?
  end

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, underscore.camelize)
    end
  end

  def test_camelize_lower
    assert_equal("capital", "Capital".camelize(:lower))
  end

  def test_camelize_upper
    assert_equal("Capital", "Capital".camelize(:upper))
  end

  def test_camelize_invalid_option
    e = assert_raise ArgumentError do
      "Capital".camelize(nil)
    end
    assert_equal("Invalid option, use either :upper or :lower.", e.message)
  end

  def test_dasherize
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(dasherized, underscored.dasherize)
    end
  end

  def test_underscore
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore, camel.underscore)
    end

    assert_equal "html_tidy", "HTMLTidy".underscore
    assert_equal "html_tidy_generator", "HTMLTidyGenerator".underscore
  end

  def test_underscore_to_lower_camel
    UnderscoreToLowerCamel.each do |underscored, lower_camel|
      assert_equal(lower_camel, underscored.camelize(:lower))
    end
  end

  def test_demodulize
    assert_equal "Account", "MyApplication::Billing::Account".demodulize
  end

  def test_deconstantize
    assert_equal "MyApplication::Billing", "MyApplication::Billing::Account".deconstantize
  end

  def test_foreign_key
    ClassNameToForeignKeyWithUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, klass.foreign_key)
    end

    ClassNameToForeignKeyWithoutUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, klass.foreign_key(false))
    end
  end

  def test_tableize
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(table_name, class_name.tableize)
    end
  end

  def test_classify
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name, table_name.classify)
    end
  end

  def test_string_parameterized_normal
    StringToParameterized.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize)
    end
  end

  def test_string_parameterized_normal_preserve_case
    StringToParameterizedPreserveCase.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize(preserve_case: true))
    end
  end

  def test_string_parameterized_no_separator
    StringToParameterizeWithNoSeparator.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize(separator: ""))
    end
  end

  def test_string_parameterized_no_separator_preserve_case
    StringToParameterizePreserveCaseWithNoSeparator.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize(separator: "", preserve_case: true))
    end
  end

  def test_string_parameterized_underscore
    StringToParameterizeWithUnderscore.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize(separator: "_"))
    end
  end

  def test_string_parameterized_underscore_preserve_case
    StringToParameterizePreserveCaseWithUnderscore.each do |normal, slugged|
      assert_equal(slugged, normal.parameterize(separator: "_", preserve_case: true))
    end
  end

  def test_parameterize_with_locale
    word = "Fünf autos"
    I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { "ü" => "ue" } } })
    assert_equal("fuenf-autos", word.parameterize(locale: :de))
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, underscore.humanize)
    end
  end

  def test_humanize_without_capitalize
    UnderscoreToHumanWithoutCapitalize.each do |underscore, human|
      assert_equal(human, underscore.humanize(capitalize: false))
    end
  end

  def test_humanize_with_keep_id_suffix
    UnderscoreToHumanWithKeepIdSuffix.each do |underscore, human|
      assert_equal(human, underscore.humanize(keep_id_suffix: true))
    end
  end

  def test_humanize_with_html_escape
    assert_equal "Hello", ERB::Util.html_escape("hello").humanize
  end

  def test_ord
    assert_equal 97, "a".ord
    assert_equal 97, "abc".ord
  end

  def test_starts_ends_with_alias
    s = "hello"
    assert s.starts_with?("h")
    assert s.starts_with?("hel")
    assert_not s.starts_with?("el")

    assert s.ends_with?("o")
    assert s.ends_with?("lo")
    assert_not s.ends_with?("el")
  end

  def test_string_squish
    original = +%{\u205f\u3000 A string surrounded by various unicode spaces,
      with tabs(\t\t), newlines(\n\n), unicode nextlines(\u0085\u0085) and many spaces(  ). \u00a0\u2007}

    expected = "A string surrounded by various unicode spaces, " \
      "with tabs( ), newlines( ), unicode nextlines( ) and many spaces( )."

    # Make sure squish returns what we expect:
    assert_equal expected, original.squish
    # But doesn't modify the original string:
    assert_not_equal expected, original

    # Make sure squish! returns what we expect:
    assert_equal expected, original.squish!
    # And changes the original string:
    assert_equal expected, original
  end

  def test_string_inquiry
    assert_predicate "production".inquiry, :production?
    assert_not_predicate "production".inquiry, :development?
  end

  def test_truncate
    assert_equal "Hello World!", "Hello World!".truncate(12)
    assert_equal "Hello Wor...", "Hello World!!".truncate(12)
  end

  def test_truncate_with_omission_and_separator
    assert_equal "Hello[...]", "Hello World!".truncate(10, omission: "[...]")
    assert_equal "Hello[...]", "Hello Big World!".truncate(13, omission: "[...]", separator: " ")
    assert_equal "Hello Big[...]", "Hello Big World!".truncate(14, omission: "[...]", separator: " ")
    assert_equal "Hello Big[...]", "Hello Big World!".truncate(15, omission: "[...]", separator: " ")
  end

  def test_truncate_with_omission_and_regexp_separator
    assert_equal "Hello[...]", "Hello Big World!".truncate(13, omission: "[...]", separator: /\s/)
    assert_equal "Hello Big[...]", "Hello Big World!".truncate(14, omission: "[...]", separator: /\s/)
    assert_equal "Hello Big[...]", "Hello Big World!".truncate(15, omission: "[...]", separator: /\s/)
  end

  def test_truncate_returns_frozen_string
    assert_not "Hello World!".truncate(12).frozen?
    assert_not "Hello World!!".truncate(12).frozen?
  end

  def test_truncate_bytes
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16)
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: nil)
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: " ")
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: "🖖")

    assert_equal "👍👍👍…", "👍👍👍👍".truncate_bytes(15)
    assert_equal "👍👍👍", "👍👍👍👍".truncate_bytes(15, omission: nil)
    assert_equal "👍👍👍 ", "👍👍👍👍".truncate_bytes(15, omission: " ")
    assert_equal "👍👍🖖", "👍👍👍👍".truncate_bytes(15, omission: "🖖")

    assert_equal "…", "👍👍👍👍".truncate_bytes(5)
    assert_equal "👍", "👍👍👍👍".truncate_bytes(5, omission: nil)
    assert_equal "👍 ", "👍👍👍👍".truncate_bytes(5, omission: " ")
    assert_equal "🖖", "👍👍👍👍".truncate_bytes(5, omission: "🖖")

    assert_equal "…", "👍👍👍👍".truncate_bytes(4)
    assert_equal "👍", "👍👍👍👍".truncate_bytes(4, omission: nil)
    assert_equal " ", "👍👍👍👍".truncate_bytes(4, omission: " ")
    assert_equal "🖖", "👍👍👍👍".truncate_bytes(4, omission: "🖖")

    assert_raise ArgumentError do
      "👍👍👍👍".truncate_bytes(3, omission: "🖖")
    end
  end

  def test_truncate_bytes_preserves_codepoints
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16)
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: nil)
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: " ")
    assert_equal "👍👍👍👍", "👍👍👍👍".truncate_bytes(16, omission: "🖖")

    assert_equal "👍👍👍…", "👍👍👍👍".truncate_bytes(15)
    assert_equal "👍👍👍", "👍👍👍👍".truncate_bytes(15, omission: nil)
    assert_equal "👍👍👍 ", "👍👍👍👍".truncate_bytes(15, omission: " ")
    assert_equal "👍👍🖖", "👍👍👍👍".truncate_bytes(15, omission: "🖖")

    assert_equal "…", "👍👍👍👍".truncate_bytes(5)
    assert_equal "👍", "👍👍👍👍".truncate_bytes(5, omission: nil)
    assert_equal "👍 ", "👍👍👍👍".truncate_bytes(5, omission: " ")
    assert_equal "🖖", "👍👍👍👍".truncate_bytes(5, omission: "🖖")

    assert_equal "…", "👍👍👍👍".truncate_bytes(4)
    assert_equal "👍", "👍👍👍👍".truncate_bytes(4, omission: nil)
    assert_equal " ", "👍👍👍👍".truncate_bytes(4, omission: " ")
    assert_equal "🖖", "👍👍👍👍".truncate_bytes(4, omission: "🖖")

    assert_raise ArgumentError do
      "👍👍👍👍".truncate_bytes(3, omission: "🖖")
    end
  end

  def test_truncates_bytes_preserves_grapheme_clusters
    assert_equal "a ", "a ❤️ b".truncate_bytes(2, omission: nil)
    assert_equal "a ", "a ❤️ b".truncate_bytes(3, omission: nil)
    assert_equal "a ", "a ❤️ b".truncate_bytes(7, omission: nil)
    assert_equal "a ❤️", "a ❤️ b".truncate_bytes(8, omission: nil)

    assert_equal "a ", "a 👩‍❤️‍👩".truncate_bytes(13, omission: nil)
    assert_equal "", "👩‍❤️‍👩".truncate_bytes(13, omission: nil)
  end

  def test_truncates_bytes_preserves_encoding
    original = String.new("a" * 30, encoding: Encoding::UTF_8)

    assert_equal Encoding::UTF_8, original.truncate_bytes(15).encoding
    assert_equal Encoding::UTF_8, original.truncate_bytes(15, omission: nil).encoding
    assert_equal Encoding::UTF_8, original.truncate_bytes(15, omission: " ").encoding
    assert_equal Encoding::UTF_8, original.truncate_bytes(15, omission: "🖖").encoding
  end

  def test_truncate_words
    assert_equal "Hello Big World!", "Hello Big World!".truncate_words(3)
    assert_equal "Hello Big...", "Hello Big World!".truncate_words(2)
  end

  def test_truncate_words_with_omission
    assert_equal "Hello Big World!", "Hello Big World!".truncate_words(3, omission: "[...]")
    assert_equal "Hello Big[...]", "Hello Big World!".truncate_words(2, omission: "[...]")
  end

  def test_truncate_words_with_separator
    assert_equal "Hello<br>Big<br>World!...", "Hello<br>Big<br>World!<br>".truncate_words(3, separator: "<br>")
    assert_equal "Hello<br>Big<br>World!", "Hello<br>Big<br>World!".truncate_words(3, separator: "<br>")
    assert_equal "Hello\n<br>Big...", "Hello\n<br>Big<br>Wide<br>World!".truncate_words(2, separator: "<br>")
  end

  def test_truncate_words_with_separator_and_omission
    assert_equal "Hello<br>Big<br>World![...]", "Hello<br>Big<br>World!<br>".truncate_words(3, omission: "[...]", separator: "<br>")
    assert_equal "Hello<br>Big<br>World!", "Hello<br>Big<br>World!".truncate_words(3, omission: "[...]", separator: "<br>")
  end

  def test_truncate_words_with_complex_string
    Timeout.timeout(10) do
      complex_string = "aa aa aaa aa aaa aaa aaa aa aaa aaa aaa aaa aaa aaa aaa aaa aaa aaa aaaa aaaaa aaaaa aaaaaa aa aa aa aaa aa  aaa aa aa aa aa a aaa aaa \n a aaa <<s"
      assert_equal complex_string, complex_string.truncate_words(80)
    end
  rescue Timeout::Error
    assert false
  end

  def test_truncate_multibyte
    assert_equal (+"\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 ...").force_encoding(Encoding::UTF_8),
      (+"\354\225\204\353\246\254\353\236\221 \354\225\204\353\246\254 \354\225\204\353\235\274\353\246\254\354\230\244").force_encoding(Encoding::UTF_8).truncate(10)
  end

  def test_truncate_should_not_be_html_safe
    assert_not_predicate "Hello World!".truncate(12), :html_safe?
  end

  def test_remove
    original = "This is a good day to die"
    assert_equal "This is a good day", original.remove(" to die")
    assert_equal "This is a good day", original.remove(" to ", /die/)
    assert_equal "This is a good day to die", original
  end

  def test_remove_for_multiple_occurrences
    original = "This is a good day to die to die"
    assert_equal "This is a good day", original.remove(" to die")
    assert_equal "This is a good day to die to die", original
  end

  def test_remove!
    original = +"This is a very good day to die"
    assert_equal "This is a good day to die", original.remove!(" very")
    assert_equal "This is a good day to die", original
    assert_equal "This is a good day", original.remove!(" to ", /die/)
    assert_equal "This is a good day", original
  end

  def test_constantize
    run_constantize_tests_on(&:constantize)
  end

  def test_safe_constantize
    run_safe_constantize_tests_on(&:safe_constantize)
  end
end

class StringAccessTest < ActiveSupport::TestCase
  test "#at with Integer, returns a substring of one character at that position" do
    assert_equal "h", "hello".at(0)
  end

  test "#at with Range, returns a substring containing characters at offsets" do
    assert_equal "lo", "hello".at(-2..-1)
  end

  test "#at with Regex, returns the matching portion of the string" do
    assert_equal "lo", "hello".at(/lo/)
    assert_nil "hello".at(/nonexisting/)
  end

  test "#from with positive Integer, returns substring from the given position to the end" do
    assert_equal "llo", "hello".from(2)
  end

  test "#from with negative Integer, position is counted from the end" do
    assert_equal "lo", "hello".from(-2)
  end

  test "#to with positive Integer, substring from the beginning to the given position" do
    assert_equal "hel", "hello".to(2)
  end

  test "#to with negative Integer, position is counted from the end" do
    assert_equal "hell", "hello".to(-2)
    assert_equal "h", "hello".to(-5)
    assert_equal "", "hello".to(-7)
  end

  test "#from and #to can be combined" do
    assert_equal "hello", "hello".from(0).to(-1)
    assert_equal "ell", "hello".from(1).to(-2)
  end

  test "#first returns the first character" do
    assert_equal "h", "hello".first
    assert_equal "x", "x".first
  end

  test "#first with Integer, returns a substring from the beginning to position" do
    assert_equal "he", "hello".first(2)
    assert_equal "", "hello".first(0)
    assert_equal "hello", "hello".first(10)
    assert_equal "x", "x".first(4)
  end

  test "#first with Integer >= string length still returns a new string" do
    string = "hello"
    different_string = string.first(5)
    assert_not_same different_string, string
  end

  test "#first with Integer returns a non-frozen string" do
    string = "he"
    (0..string.length + 1).each do |limit|
      assert_not string.first(limit).frozen?
    end
  end

  test "#first with negative Integer raises ArgumentError" do
    assert_raise ArgumentError do
      "hello".first(-1)
    end
  end

  test "#last returns the last character" do
    assert_equal "o", "hello".last
    assert_equal "x", "x".last
  end

  test "#last with Integer, returns a substring from the end to position" do
    assert_equal "llo", "hello".last(3)
    assert_equal "hello", "hello".last(10)
    assert_equal "", "hello".last(0)
    assert_equal "x", "x".last(4)
  end

  test "#last with Integer >= string length still returns a new string" do
    string = "hello"
    different_string = string.last(5)
    assert_not_same different_string, string
  end

  test "#last with Integer returns a non-frozen string" do
    string = "he"
    (0..string.length + 1).each do |limit|
      assert_not string.last(limit).frozen?
    end
  end

  test "#last with negative Integer raises ArgumentError" do
    assert_raise ArgumentError do
      "hello".last(-1)
    end
  end

  test "access returns a real string" do
    hash = {}
    hash["h"] = true
    hash["hello123".at(0)] = true
    assert_equal %w(h), hash.keys

    hash = {}
    hash["llo"] = true
    hash["hello".from(2)] = true
    assert_equal %w(llo), hash.keys

    hash = {}
    hash["hel"] = true
    hash["hello".to(2)] = true
    assert_equal %w(hel), hash.keys

    hash = {}
    hash["hello"] = true
    hash["123hello".last(5)] = true
    assert_equal %w(hello), hash.keys

    hash = {}
    hash["hello"] = true
    hash["hello123".first(5)] = true
    assert_equal %w(hello), hash.keys
  end
end

class StringConversionsTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def test_string_to_time
    with_env_tz "Europe/Moscow" do
      assert_equal Time.utc(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time(:utc)
      assert_equal Time.local(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time
      assert_equal Time.utc(2005, 2, 27, 23, 50, 19, 275038), "2005-02-27T23:50:19.275038".to_time(:utc)
      assert_equal Time.local(2005, 2, 27, 23, 50, 19, 275038), "2005-02-27T23:50:19.275038".to_time
      assert_equal Time.utc(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_time(:utc)
      assert_equal Time.local(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_time
      assert_equal Time.local(2011, 2, 27, 17, 50), "2011-02-27 13:50 -0100".to_time
      assert_equal Time.utc(2011, 2, 27, 23, 50), "2011-02-27 22:50 -0100".to_time(:utc)
      assert_equal Time.local(2005, 2, 27, 22, 50), "2005-02-27 14:50 -0500".to_time
      assert_nil "010".to_time
      assert_nil "".to_time
    end
  end

  def test_timestamp_string_to_time
    exception = assert_raises(ArgumentError) do
      "1604326192".to_time
    end

    assert_equal "argument out of range", exception.message
  end

  def test_string_to_time_utc_offset
    with_env_tz "US/Eastern" do
      if ActiveSupport.to_time_preserves_timezone
        assert_equal 0, "2005-02-27 23:50".to_time(:utc).utc_offset
        assert_equal(-18000, "2005-02-27 23:50".to_time.utc_offset)
        assert_equal 0, "2005-02-27 22:50 -0100".to_time(:utc).utc_offset
        assert_equal(-3600, "2005-02-27 22:50 -0100".to_time.utc_offset)
      else
        assert_equal 0, "2005-02-27 23:50".to_time(:utc).utc_offset
        assert_equal(-18000, "2005-02-27 23:50".to_time.utc_offset)
        assert_equal 0, "2005-02-27 22:50 -0100".to_time(:utc).utc_offset
        assert_equal(-18000, "2005-02-27 22:50 -0100".to_time.utc_offset)
      end
    end
  end

  def test_partial_string_to_time
    with_env_tz "Europe/Moscow" do # use timezone which does not observe DST.
      now = Time.now
      assert_equal Time.local(now.year, now.month, now.day, 23, 50), "23:50".to_time
      assert_equal Time.utc(now.year, now.month, now.day, 23, 50), "23:50".to_time(:utc)
      assert_equal Time.local(now.year, now.month, now.day, 17, 50), "13:50 -0100".to_time
      assert_equal Time.utc(now.year, now.month, now.day, 23, 50), "22:50 -0100".to_time(:utc)
    end
  end

  def test_standard_time_string_to_time_when_current_time_is_standard_time
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 1, 1)) do
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0), "2012-01-01 10:00".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 13, 0), "2012-01-01 10:00 -0800".to_time
        assert_equal Time.utc(2012, 1, 1, 18, 0), "2012-01-01 10:00 -0800".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00 -0500".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "2012-01-01 10:00 -0500".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 5, 0), "2012-01-01 10:00 UTC".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0), "2012-01-01 10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 13, 0), "2012-01-01 10:00 PST".to_time
        assert_equal Time.utc(2012, 1, 1, 18, 0), "2012-01-01 10:00 PST".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00 EST".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "2012-01-01 10:00 EST".to_time(:utc)
      end
    end
  end

  def test_standard_time_string_to_time_when_current_time_is_daylight_savings
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 7, 1)) do
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0), "2012-01-01 10:00".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 13, 0), "2012-01-01 10:00 -0800".to_time
        assert_equal Time.utc(2012, 1, 1, 18, 0), "2012-01-01 10:00 -0800".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00 -0500".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "2012-01-01 10:00 -0500".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 5, 0), "2012-01-01 10:00 UTC".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0), "2012-01-01 10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 13, 0), "2012-01-01 10:00 PST".to_time
        assert_equal Time.utc(2012, 1, 1, 18, 0), "2012-01-01 10:00 PST".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "2012-01-01 10:00 EST".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "2012-01-01 10:00 EST".to_time(:utc)
      end
    end
  end

  def test_daylight_savings_string_to_time_when_current_time_is_standard_time
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 1, 1)) do
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "2012-07-01 10:00".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 13, 0), "2012-07-01 10:00 -0700".to_time
        assert_equal Time.utc(2012, 7, 1, 17, 0), "2012-07-01 10:00 -0700".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00 -0400".to_time
        assert_equal Time.utc(2012, 7, 1, 14, 0), "2012-07-01 10:00 -0400".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 6, 0), "2012-07-01 10:00 UTC".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "2012-07-01 10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 13, 0), "2012-07-01 10:00 PDT".to_time
        assert_equal Time.utc(2012, 7, 1, 17, 0), "2012-07-01 10:00 PDT".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00 EDT".to_time
        assert_equal Time.utc(2012, 7, 1, 14, 0), "2012-07-01 10:00 EDT".to_time(:utc)
      end
    end
  end

  def test_daylight_savings_string_to_time_when_current_time_is_daylight_savings
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 7, 1)) do
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "2012-07-01 10:00".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 13, 0), "2012-07-01 10:00 -0700".to_time
        assert_equal Time.utc(2012, 7, 1, 17, 0), "2012-07-01 10:00 -0700".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00 -0400".to_time
        assert_equal Time.utc(2012, 7, 1, 14, 0), "2012-07-01 10:00 -0400".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 6, 0), "2012-07-01 10:00 UTC".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "2012-07-01 10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 13, 0), "2012-07-01 10:00 PDT".to_time
        assert_equal Time.utc(2012, 7, 1, 17, 0), "2012-07-01 10:00 PDT".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 10, 0), "2012-07-01 10:00 EDT".to_time
        assert_equal Time.utc(2012, 7, 1, 14, 0), "2012-07-01 10:00 EDT".to_time(:utc)
      end
    end
  end

  def test_partial_string_to_time_when_current_time_is_standard_time
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 1, 1)) do
        assert_equal Time.local(2012, 1, 1, 10, 0), "10:00".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0),  "10:00".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 6, 0), "10:00 -0100".to_time
        assert_equal Time.utc(2012, 1, 1, 11, 0), "10:00 -0100".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "10:00 -0500".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "10:00 -0500".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 5, 0), "10:00 UTC".to_time
        assert_equal Time.utc(2012, 1, 1, 10, 0), "10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 13, 0), "10:00 PST".to_time
        assert_equal Time.utc(2012, 1, 1, 18, 0), "10:00 PST".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 12, 0), "10:00 PDT".to_time
        assert_equal Time.utc(2012, 1, 1, 17, 0), "10:00 PDT".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 10, 0), "10:00 EST".to_time
        assert_equal Time.utc(2012, 1, 1, 15, 0), "10:00 EST".to_time(:utc)
        assert_equal Time.local(2012, 1, 1, 9, 0), "10:00 EDT".to_time
        assert_equal Time.utc(2012, 1, 1, 14, 0), "10:00 EDT".to_time(:utc)
      end
    end
  end

  def test_partial_string_to_time_when_current_time_is_daylight_savings
    with_env_tz "US/Eastern" do
      Time.stub(:now, Time.local(2012, 7, 1)) do
        assert_equal Time.local(2012, 7, 1, 10, 0), "10:00".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "10:00".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 7, 0), "10:00 -0100".to_time
        assert_equal Time.utc(2012, 7, 1, 11, 0), "10:00 -0100".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 11, 0), "10:00 -0500".to_time
        assert_equal Time.utc(2012, 7, 1, 15, 0), "10:00 -0500".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 6, 0), "10:00 UTC".to_time
        assert_equal Time.utc(2012, 7, 1, 10, 0), "10:00 UTC".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 14, 0), "10:00 PST".to_time
        assert_equal Time.utc(2012, 7, 1, 18, 0), "10:00 PST".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 13, 0), "10:00 PDT".to_time
        assert_equal Time.utc(2012, 7, 1, 17, 0), "10:00 PDT".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 11, 0), "10:00 EST".to_time
        assert_equal Time.utc(2012, 7, 1, 15, 0), "10:00 EST".to_time(:utc)
        assert_equal Time.local(2012, 7, 1, 10, 0), "10:00 EDT".to_time
        assert_equal Time.utc(2012, 7, 1, 14, 0), "10:00 EDT".to_time(:utc)
      end
    end
  end

  def test_string_to_datetime
    assert_equal DateTime.civil(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_datetime
    assert_equal 0, "2039-02-27 23:50".to_datetime.offset # use UTC offset
    assert_equal ::Date::ITALY, "2039-02-27 23:50".to_datetime.start # use Ruby's default start value
    assert_equal DateTime.civil(2039, 2, 27, 23, 50, 19 + Rational(275038, 1000000), "-04:00"), "2039-02-27T23:50:19.275038-04:00".to_datetime
    assert_nil "".to_datetime
  end

  def test_partial_string_to_datetime
    now = DateTime.now
    assert_equal DateTime.civil(now.year, now.month, now.day, 23, 50), "23:50".to_datetime
    assert_equal DateTime.civil(now.year, now.month, now.day, 23, 50, 0, "-04:00"), "23:50 -0400".to_datetime
  end

  def test_string_to_date
    assert_equal Date.new(2005, 2, 27), "2005-02-27".to_date
    assert_nil "".to_date
    assert_equal Date.new(Date.today.year, 2, 3), "Feb 3rd".to_date
  end
end

class StringBehaviorTest < ActiveSupport::TestCase
  def test_acts_like_string
    assert_predicate "Bambi", :acts_like_string?
  end
end

class CoreExtStringMultibyteTest < ActiveSupport::TestCase
  UTF8_STRING = "こにちわ"
  ASCII_STRING = "ohayo".encode("US-ASCII")
  EUC_JP_STRING = "さよなら".encode("EUC-JP")
  INVALID_UTF8_STRING = "\270\236\010\210\245"

  def test_core_ext_adds_mb_chars
    assert_respond_to UTF8_STRING, :mb_chars
  end

  def test_string_should_recognize_utf8_strings
    assert_predicate UTF8_STRING, :is_utf8?
    assert_predicate ASCII_STRING, :is_utf8?
    assert_not_predicate EUC_JP_STRING, :is_utf8?
    assert_not_predicate INVALID_UTF8_STRING, :is_utf8?
  end

  def test_mb_chars_returns_instance_of_proxy_class
    assert_deprecated ActiveSupport.deprecator do
      assert_kind_of ActiveSupport::Multibyte.proxy_class, UTF8_STRING.mb_chars
    end
  end
end

class OutputSafetyTest < ActiveSupport::TestCase
  def setup
    @string = +"hello"
    @object = Class.new(Object) do
      def to_str
        "other"
      end
    end.new
    @to_s_object = Class.new(Object) do
      def to_s
        "to_s"
      end
    end.new
  end

  test "A string is unsafe by default" do
    assert_not_predicate @string, :html_safe?
  end

  test "A string can be marked safe" do
    string = @string.html_safe
    assert_predicate string, :html_safe?
  end

  test "Marking a string safe returns the string" do
    assert_equal @string, @string.html_safe
  end

  test "An integer is safe by default" do
    assert_predicate 5, :html_safe?
  end

  test "a float is safe by default" do
    assert_predicate 5.7, :html_safe?
  end

  test "An object is unsafe by default" do
    assert_not_predicate @object, :html_safe?
  end

  test "Adding an object not responding to `#to_str` to a safe string is deprecated" do
    string = @string.html_safe
    assert_raises(NoMethodError) do
      string << @to_s_object
    end
  end

  test "Adding an object to a safe string returns a safe string" do
    string = @string.html_safe
    string << @object

    assert_equal "helloother", string
    assert_predicate string, :html_safe?
  end

  test "Adding a safe string to another safe string returns a safe string" do
    @other_string = "other".html_safe
    string = @string.html_safe
    @combination = @other_string + string

    assert_equal "otherhello", @combination
    assert_predicate @combination, :html_safe?
  end

  test "Adding an unsafe string to a safe string escapes it and returns a safe string" do
    @other_string = "other".html_safe
    @combination = @other_string + "<foo>"
    @other_combination = @string + "<foo>"

    assert_equal "other&lt;foo&gt;", @combination
    assert_equal "hello<foo>", @other_combination

    assert_predicate @combination, :html_safe?
    assert_not_predicate @other_combination, :html_safe?
  end

  test "Prepending safe onto unsafe yields unsafe" do
    @string.prepend "other".html_safe
    assert_not_predicate @string, :html_safe?
    assert_equal "otherhello", @string
  end

  test "Prepending unsafe onto safe yields escaped safe" do
    other = "other".html_safe
    other.prepend "<foo>"
    assert_predicate other, :html_safe?
    assert_equal "&lt;foo&gt;other", other
  end

  test "Concatting safe onto unsafe yields unsafe" do
    @other_string = +"other"

    string = @string.html_safe
    @other_string.concat(string)
    assert_not_predicate @other_string, :html_safe?
  end

  test "Concatting unsafe onto safe yields escaped safe" do
    @other_string = "other".html_safe
    string = @other_string.concat("<foo>")
    assert_equal "other&lt;foo&gt;", string
    assert_predicate string, :html_safe?
  end

  test "Concatting safe onto safe yields safe" do
    @other_string = "other".html_safe
    string = @string.html_safe

    @other_string.concat(string)
    assert_predicate @other_string, :html_safe?
  end

  test "Concatting safe onto unsafe with << yields unsafe" do
    @other_string = +"other"
    string = @string.html_safe

    @other_string << string
    assert_not_predicate @other_string, :html_safe?
  end

  test "Concatting unsafe onto safe with << yields escaped safe" do
    @other_string = "other".html_safe
    string = @other_string << "<foo>"
    assert_equal "other&lt;foo&gt;", string
    assert_predicate string, :html_safe?
  end

  test "Concatting safe onto safe with << yields safe" do
    @other_string = "other".html_safe
    string = @string.html_safe

    @other_string << string
    assert_predicate @other_string, :html_safe?
  end

  test "Concatting safe onto unsafe with % yields unsafe" do
    @other_string = "other%s"
    string = @string.html_safe

    @other_string = @other_string % string
    assert_not_predicate @other_string, :html_safe?
  end

  test "% method explicitly cast the argument to string" do
    @other_string = "other%s"
    assert_equal "otherto_s", @other_string % @to_s_object
  end

  test "Concatting unsafe onto safe with % yields escaped safe" do
    @other_string = "other%s".html_safe
    string = @other_string % "<foo>"

    assert_equal "other&lt;foo&gt;", string
    assert_predicate string, :html_safe?
  end

  test "Concatting safe onto safe with % yields safe" do
    @other_string = "other%s".html_safe
    string = @string.html_safe

    @other_string = @other_string % string
    assert_predicate @other_string, :html_safe?
  end

  test "Concatting with % doesn't modify a string" do
    @other_string = ["<p>", "<b>", "<h1>"]
    _ = "%s %s %s".html_safe % @other_string

    assert_equal ["<p>", "<b>", "<h1>"], @other_string
  end

  test "Concatting an integer to safe always yields safe" do
    string = @string.html_safe
    string = string.concat(13)
    assert_equal (+"hello").concat(13), string
    assert_predicate string, :html_safe?
  end

  test "Inserting safe into safe yields safe" do
    string = "foo".html_safe
    string.insert(0, "<b>".html_safe)

    assert_equal "<b>foo", string
    assert_predicate string, :html_safe?
  end

  test "Inserting unsafe into safe yields escaped safe" do
    string = "foo".html_safe
    string.insert(0, "<b>")

    assert_equal "&lt;b&gt;foo", string
    assert_predicate string, :html_safe?
  end

  test "Replacing safe with safe yields safe" do
    string = "foo".html_safe
    string.replace("<b>".html_safe)

    assert_equal "<b>", string
    assert_predicate string, :html_safe?
  end

  test "Replacing safe with unsafe yields escaped safe" do
    string = "foo".html_safe
    string.replace("<b>")

    assert_equal "&lt;b&gt;", string
    assert_predicate string, :html_safe?
  end

  test "Replacing index of safe with safe yields safe" do
    string = "foo".html_safe
    string[0] = "<b>".html_safe

    assert_equal "<b>oo", string
    assert_predicate string, :html_safe?

    string = "foo".html_safe
    string[0, 2] = "<b>".html_safe

    assert_equal "<b>o", string
    assert_predicate string, :html_safe?
  end

  test "Replacing index of safe with unsafe yields escaped safe" do
    string = "foo".html_safe
    string[0] = "<b>"

    assert_equal "&lt;b&gt;oo", string
    assert_predicate string, :html_safe?

    string = "foo".html_safe
    string[1, 1] = "<b>"

    assert_equal "f&lt;b&gt;o", string
    assert_predicate string, :html_safe?
  end

  if "".respond_to?(:bytesplice)
    test "Bytesplicing safe into safe yields safe" do
      string = "hello".html_safe
      string.bytesplice(0, 0, "<b>".html_safe)

      assert_equal "<b>hello", string
      assert_predicate string, :html_safe?

      string = "hello".html_safe
      string.bytesplice(0..1, "<b>".html_safe)

      assert_equal "<b>llo", string
      assert_predicate string, :html_safe?
    end

    test "Bytesplicing unsafe into safe yields escaped safe" do
      string = "hello".html_safe
      string.bytesplice(1, 0, "<b>")

      assert_equal "h&lt;b&gt;ello", string
      assert_predicate string, :html_safe?

      string = "hello".html_safe
      string.bytesplice(1..2, "<b>")

      assert_equal "h&lt;b&gt;lo", string
      assert_predicate string, :html_safe?
    end
  end

  test "emits normal string YAML" do
    assert_equal "foo".to_yaml, "foo".html_safe.to_yaml(foo: 1)
  end

  test "call to_param returns a normal string" do
    string = @string.html_safe
    assert_predicate string, :html_safe?
    assert_not_predicate string.to_param, :html_safe?
  end

  test "ERB::Util.html_escape should escape unsafe characters" do
    string = '<>&"\''
    expected = "&lt;&gt;&amp;&quot;&#39;"
    assert_equal expected, ERB::Util.html_escape(string)
  end

  test "ERB::Util.html_escape should correctly handle invalid UTF-8 strings" do
    string = "\251 <"
    expected = "© &lt;"
    assert_equal expected, ERB::Util.html_escape(string)
  end

  test "ERB::Util.html_escape should not escape safe strings" do
    string = "<b>hello</b>".html_safe
    assert_equal string, ERB::Util.html_escape(string)
  end

  test "ERB::Util.html_escape_once only escapes once" do
    string = "1 < 2 &amp; 3"
    escaped_string = "1 &lt; 2 &amp; 3"

    assert_equal escaped_string, ERB::Util.html_escape_once(string)
    assert_equal escaped_string, ERB::Util.html_escape_once(escaped_string)
  end

  test "ERB::Util.html_escape_once should correctly handle invalid UTF-8 strings" do
    string = "\251 <"
    expected = "© &lt;"
    assert_equal expected, ERB::Util.html_escape_once(string)
  end

  test "ERB::Util.xml_name_escape should escape unsafe characters for XML names" do
    unsafe_char = ">"
    safe_char = "Á"
    safe_char_after_start = "3"
    starting_with_dash = "-foo"

    assert_equal "_", ERB::Util.xml_name_escape(unsafe_char)
    assert_equal "_#{safe_char}", ERB::Util.xml_name_escape(unsafe_char + safe_char)
    assert_equal "__", ERB::Util.xml_name_escape(unsafe_char * 2)

    assert_equal "__#{safe_char}_",
                 ERB::Util.xml_name_escape("#{unsafe_char * 2}#{safe_char}#{unsafe_char}")

    assert_equal safe_char + safe_char_after_start,
                 ERB::Util.xml_name_escape(safe_char + safe_char_after_start)

    assert_equal "_#{safe_char}",
                 ERB::Util.xml_name_escape(safe_char_after_start + safe_char)

    assert_equal "img_src_nonexistent_onerror_alert_1_",
                 ERB::Util.xml_name_escape("img src=nonexistent onerror=alert(1)")

    common_dangerous_chars = "&<>\"' %*+,/;=^|"
    assert_equal "_" * common_dangerous_chars.size,
                 ERB::Util.xml_name_escape(common_dangerous_chars)

    assert_equal "_foo", ERB::Util.xml_name_escape(starting_with_dash)
  end
end

class StringExcludeTest < ActiveSupport::TestCase
  test "inverse of #include" do
    assert_equal false, "foo".exclude?("o")
    assert_equal true, "foo".exclude?("p")
  end
end

class StringIndentTest < ActiveSupport::TestCase
  test "does not indent strings that only contain newlines (edge cases)" do
    ["", "\n", "\n" * 7].each do |string|
      str = string.dup
      assert_nil str.indent!(8)
      assert_equal str, str.indent(8)
      assert_equal str, str.indent(1, "\t")
    end
  end

  test "by default, indents with spaces if the existing indentation uses them" do
    assert_equal "    foo\n      bar", "foo\n  bar".indent(4)
  end

  test "by default, indents with tabs if the existing indentation uses them" do
    assert_equal "\tfoo\n\t\t\bar", "foo\n\t\bar".indent(1)
  end

  test "by default, indents with spaces as a fallback if there is no indentation" do
    assert_equal "   foo\n   bar\n   baz", "foo\nbar\nbaz".indent(3)
  end

  # Nothing is said about existing indentation that mixes spaces and tabs, so
  # there is nothing to test.

  test "uses the indent char if passed" do
    assert_equal <<EXPECTED, <<ACTUAL.indent(4, ".")
....  def some_method(x, y)
....    some_code
....  end
EXPECTED
  def some_method(x, y)
    some_code
  end
ACTUAL

    assert_equal <<EXPECTED, <<ACTUAL.indent(2, "&nbsp;")
&nbsp;&nbsp;&nbsp;&nbsp;def some_method(x, y)
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;some_code
&nbsp;&nbsp;&nbsp;&nbsp;end
EXPECTED
&nbsp;&nbsp;def some_method(x, y)
&nbsp;&nbsp;&nbsp;&nbsp;some_code
&nbsp;&nbsp;end
ACTUAL
  end

  test "does not indent blank lines by default" do
    assert_equal " foo\n\n bar", "foo\n\nbar".indent(1)
  end

  test "indents blank lines if told so" do
    assert_equal " foo\n \n bar", "foo\n\nbar".indent(1, nil, true)
  end
end
