# encoding: utf-8
require 'date'
require 'abstract_unit'
require 'inflector_test_cases'

require 'active_support/core_ext/string'
require 'active_support/core_ext/time'

class StringInflectionsTest < Test::Unit::TestCase
  include InflectorTestCases

  def test_pluralize
    SingularToPlural.each do |singular, plural|
      assert_equal(plural, singular.pluralize)
    end

    assert_equal("plurals", "plurals".pluralize)
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

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, underscore.camelize)
    end
  end

  def test_camelize_lower
    assert_equal('capital', 'Capital'.camelize(:lower))
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
      assert_equal(normal.parameterize, slugged)
    end
  end

  def test_string_parameterized_no_separator
    StringToParameterizeWithNoSeparator.each do |normal, slugged|
      assert_equal(normal.parameterize(''), slugged)
    end
  end

  def test_string_parameterized_underscore
    StringToParameterizeWithUnderscore.each do |normal, slugged|
      assert_equal(normal.parameterize('_'), slugged)
    end
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, underscore.humanize)
    end
  end

  def test_ord
    assert_equal 97, 'a'.ord
    assert_equal 97, 'abc'.ord
  end

  def test_string_to_time
    assert_equal Time.utc(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time
    assert_equal Time.local(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time(:local)
    assert_equal Time.utc(2005, 2, 27, 23, 50, 19, 275038), "2005-02-27T23:50:19.275038".to_time
    assert_equal Time.local(2005, 2, 27, 23, 50, 19, 275038), "2005-02-27T23:50:19.275038".to_time(:local)
    assert_equal DateTime.civil(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_time
    assert_equal Time.local_time(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_time(:local)
  end
  
  def test_string_to_datetime
    assert_equal DateTime.civil(2039, 2, 27, 23, 50), "2039-02-27 23:50".to_datetime
    assert_equal 0, "2039-02-27 23:50".to_datetime.offset # use UTC offset
    assert_equal ::Date::ITALY, "2039-02-27 23:50".to_datetime.start # use Ruby's default start value
    assert_equal DateTime.civil(2039, 2, 27, 23, 50, 19 + Rational(275038, 1000000), "-04:00"), "2039-02-27T23:50:19.275038-04:00".to_datetime
  end
  
  def test_string_to_date
    assert_equal Date.new(2005, 2, 27), "2005-02-27".to_date
  end

  def test_access
    s = "hello"
    assert_equal "h", s.at(0)

    assert_equal "llo", s.from(2)
    assert_equal "hel", s.to(2)

    assert_equal "h", s.first
    assert_equal "he", s.first(2)
    assert_equal "", s.first(0)

    assert_equal "o", s.last
    assert_equal "llo", s.last(3)
    assert_equal "hello", s.last(10)
    assert_equal "", s.last(0)

    assert_equal 'x', 'x'.first
    assert_equal 'x', 'x'.first(4)

    assert_equal 'x', 'x'.last
    assert_equal 'x', 'x'.last(4)
  end

  def test_access_returns_a_real_string
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

  def test_starts_ends_with_alias
    s = "hello"
    assert s.starts_with?('h')
    assert s.starts_with?('hel')
    assert !s.starts_with?('el')

    assert s.start_with?('h')
    assert s.start_with?('hel')
    assert !s.start_with?('el')

    assert s.ends_with?('o')
    assert s.ends_with?('lo')
    assert !s.ends_with?('el')

    assert s.end_with?('o')
    assert s.end_with?('lo')
    assert !s.end_with?('el')
  end

  def test_string_squish
    original = %{ A string with tabs(\t\t), newlines(\n\n), and
                  many spaces(  ). }

    expected = "A string with tabs( ), newlines( ), and many spaces( )."

    # Make sure squish returns what we expect:
    assert_equal original.squish,  expected
    # But doesn't modify the original string:
    assert_not_equal original, expected

    # Make sure squish! returns what we expect:
    assert_equal original.squish!, expected
    # And changes the original string:
    assert_equal original, expected
  end

  if RUBY_VERSION < '1.9'
    def test_each_char_with_utf8_string_when_kcode_is_utf8
      with_kcode('UTF8') do
        '€2.99'.each_char do |char|
          assert_not_equal 1, char.length
          break
        end
      end
    end
  end
end

class StringBehaviourTest < Test::Unit::TestCase
  def test_acts_like_string
    assert 'Bambi'.acts_like_string?
  end
end

class CoreExtStringMultibyteTest < ActiveSupport::TestCase
  UNICODE_STRING = 'こにちわ'
  ASCII_STRING = 'ohayo'
  BYTE_STRING = "\270\236\010\210\245"

  def test_core_ext_adds_mb_chars
    assert UNICODE_STRING.respond_to?(:mb_chars)
  end

  def test_string_should_recognize_utf8_strings
    assert UNICODE_STRING.is_utf8?
    assert ASCII_STRING.is_utf8?
    assert !BYTE_STRING.is_utf8?
  end

  if RUBY_VERSION < '1.8.7'
    def test_core_ext_adds_chars
      assert UNICODE_STRING.respond_to?(:chars)
    end

    def test_chars_warns_about_deprecation
      assert_deprecated("String#chars") do
        ''.chars
      end
    end
  end

  if RUBY_VERSION < '1.9'
    def test_mb_chars_returns_self_when_kcode_not_set
      with_kcode('none') do
        assert UNICODE_STRING.mb_chars.kind_of?(String)
      end
    end

    def test_mb_chars_returns_an_instance_of_the_chars_proxy_when_kcode_utf8
      with_kcode('UTF8') do
        assert UNICODE_STRING.mb_chars.kind_of?(ActiveSupport::Multibyte.proxy_class)
      end
    end
  end

  if RUBY_VERSION >= '1.9'
    def test_mb_chars_returns_string
      assert UNICODE_STRING.mb_chars.kind_of?(String)
    end
  end
end

=begin
  string.rb - Interpolation for String.

  Copyright (C) 2005-2009 Masao Mutoh
 
  You may redistribute it and/or modify it under the same
  license terms as Ruby.
=end
class TestGetTextString < Test::Unit::TestCase
  def test_sprintf
    assert_equal("foo is a number", "%{msg} is a number" % {:msg => "foo"})
    assert_equal("bar is a number", "%s is a number" % ["bar"])
    assert_equal("bar is a number", "%s is a number" % "bar")
    assert_equal("1, test", "%{num}, %{record}" % {:num => 1, :record => "test"})
    assert_equal("test, 1", "%{record}, %{num}" % {:num => 1, :record => "test"})
    assert_equal("1, test", "%d, %s" % [1, "test"])
    assert_equal("test, 1", "%2$s, %1$d" % [1, "test"])
    assert_raise(ArgumentError) { "%-%" % [1] }
  end

  def test_percent
    assert_equal("% 1", "%% %<num>d" % {:num => 1.0})
    assert_equal("%{num} %<num>d", "%%{num} %%<num>d" % {:num => 1})
  end

  def test_sprintf_percent_in_replacement
    assert_equal("%<not_translated>s", "%{msg}" % { :msg => '%<not_translated>s', :not_translated => 'should not happen' })
  end

  def test_sprintf_lack_argument
    assert_raises(KeyError) { "%{num}, %{record}" % {:record => "test"} }
    assert_raises(KeyError) { "%{record}" % {:num => 1} }
  end

  def test_no_placeholder
    assert_equal("aaa", "aaa" % {:num => 1})
    assert_equal("bbb", "bbb" % [1])
  end

  def test_sprintf_ruby19_style
    assert_equal("1", "%<num>d" % {:num => 1})
    assert_equal("0b1", "%<num>#b" % {:num => 1})
    assert_equal("foo", "%<msg>s" % {:msg => "foo"})
    assert_equal("1.000000", "%<num>f" % {:num => 1.0})
    assert_equal("  1", "%<num>3.0f" % {:num => 1.0})
    assert_equal("100.00", "%<num>2.2f" % {:num => 100.0})
    assert_equal("0x64", "%<num>#x" % {:num => 100.0})
    assert_raise(ArgumentError) { "%<num>,d" % {:num => 100} }
    assert_raise(ArgumentError) { "%<num>/d" % {:num => 100} }
  end

  def test_sprintf_old_style
    assert_equal("foo 1.000000", "%s %f" % ["foo", 1.0])
  end

  def test_sprintf_mix_unformatted_and_formatted_named_placeholders
    assert_equal("foo 1.000000", "%{name} %<num>f" % {:name => "foo", :num => 1.0})
  end

  def test_string_interpolation_raises_an_argument_error_when_mixing_named_and_unnamed_placeholders
    assert_raises(ArgumentError) { "%{name} %f" % [1.0] }
    assert_raises(ArgumentError) { "%{name} %f" % [1.0, 2.0] }
  end
end

class StringBytesizeTest < Test::Unit::TestCase
  def test_bytesize
    assert_respond_to 'foo', :bytesize
    assert_equal 3, 'foo'.bytesize
  end
end
