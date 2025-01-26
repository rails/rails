# frozen_string_literal: true

require_relative "../abstract_unit"
require_relative "../inflector_test_cases"
require "active_support/core_ext/symbol"

class SymbolStartsEndsWithTest < ActiveSupport::TestCase
  def test_starts_ends_with_alias
    s = :hello
    assert s.starts_with?("h")
    assert s.starts_with?("hel")
    assert_not s.starts_with?("el")
    assert s.starts_with?("he", "lo")
    assert_not s.starts_with?("el", "lo")

    assert s.ends_with?("o")
    assert s.ends_with?("lo")
    assert_not s.ends_with?("el")
    assert s.ends_with?("he", "lo")
    assert_not s.ends_with?("he", "ll")
  end
end

class SymbolInflectionsTest < ActiveSupport::TestCase
  include InflectorTestCases

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel.to_sym, underscore.to_sym.camelize)
      assert_equal(camel.to_sym, underscore.to_sym.camelcase)
    end
  end

  def test_camelize_lower
    assert_equal(:capital, :Capital.camelize(:lower))
    assert_equal(:capital, :Capital.camelcase(:lower))
  end

  def test_camelize_upper
    assert_equal(:Capital, :Capital.camelize(:upper))
    assert_equal(:Capital, :Capital.camelcase(:upper))
  end

  def test_dasherize
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(dasherized.to_sym, underscored.to_sym.dasherize)
    end
  end

  def test_underscore
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore.to_sym, camel.to_sym.underscore)
    end

    assert_equal :html_tidy, :HTMLTidy.underscore
    assert_equal :html_tidy_generator, :HTMLTidyGenerator.underscore
  end

  def test_underscore_to_lower_camel
    UnderscoreToLowerCamel.each do |underscored, lower_camel|
      assert_equal(lower_camel.to_sym, underscored.to_sym.camelize(:lower))
    end
  end
end
