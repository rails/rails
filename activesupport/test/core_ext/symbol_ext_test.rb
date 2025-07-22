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

  def test_pluralize
    SingularToPlural.each do |singular, plural|
      assert_equal(plural.to_sym, singular.to_sym.pluralize)
    end
  end

  def test_singularize
    SingularToPlural.each do |singular, plural|
      assert_equal(singular.to_sym, plural.to_sym.singularize)
    end
  end

  def test_titleize
    MixtureToTitleCase.each do |before, titleized|
      assert_equal(titleized.to_sym, before.to_sym.titleize)
      assert_equal(titleized.to_sym, before.to_sym.titlecase)
    end
  end

  def test_downcase_first
    assert_equal :t, :T.downcase_first
  end

  def test_upcase_first
    assert_equal :What, :what.upcase_first
  end

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

  def test_demodulize
    assert_equal :Account, :"MyApplication::Billing::Account".demodulize
  end

  def test_deconstantize
    assert_equal :"MyApplication::Billing", :"MyApplication::Billing::Account".deconstantize
  end

  def test_foreign_key
    ClassNameToForeignKeyWithUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key.to_sym, klass.to_sym.foreign_key)
    end
  end

  def test_tableize
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(table_name.to_sym, class_name.to_sym.tableize)
    end
  end

  def test_classify
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name.to_sym, table_name.to_sym.classify)
    end
  end

  def test_string_parameterized_normal
    StringToParameterized.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize)
    end
  end

  def test_string_parameterized_normal_preserve_case
    StringToParameterizedPreserveCase.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize(preserve_case: true))
    end
  end

  def test_string_parameterized_no_separator
    StringToParameterizeWithNoSeparator.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize(separator: ""))
    end
  end

  def test_string_parameterized_no_separator_preserve_case
    StringToParameterizePreserveCaseWithNoSeparator.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize(separator: "", preserve_case: true))
    end
  end

  def test_string_parameterized_underscore
    StringToParameterizeWithUnderscore.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize(separator: "_"))
    end
  end

  def test_string_parameterized_underscore_preserve_case
    StringToParameterizePreserveCaseWithUnderscore.each do |normal, slugged|
      next unless encodable?(normal)

      assert_equal(slugged.to_sym, normal.to_sym.parameterize(separator: "_", preserve_case: true))
    end
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human.to_sym, underscore.to_sym.humanize)
    end
  end

  def encodable?(string)
    string.to_sym
  rescue EncodingError
    false
  end
end
