# frozen_string_literal: true

require "cases/helper"

class PostgresqlCollationAdapterTest < ActiveRecord::PostgreSQLTestCase
  LOCALE_ERROR_MESSAGE = "Either `locale' or both `lc_collate' and `lc_ctype' must be specified"

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_collations_with_postgresql_specific_schema
    assert_equal ["german"], @connection.collations
  end

  def test_collations_with_no_collations
    @connection.execute "DROP COLLATION german"
    assert_equal [], @connection.collations
  end

  def test_collations_with_multiple_collations
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"
    @connection.execute <<~SQL
      CREATE COLLATION case_insensitive
        (provider = icu, locale = 'und-u-ks-level2', deterministic = false)
    SQL

    assert_equal ["case_insensitive", "german", "japanese"], @connection.collations.sort
  end

  def test_collation_definitions_with_postgresql_specific_schema
    assert_equal 1, @connection.collation_definitions.length
    assert collation = @connection.collation_definitions.find { |c| c.name == "german" }

    assert_equal "libc", collation.provider
    assert_equal "de_DE", collation.lc_collate
    assert_equal "de_DE", collation.lc_ctype
    assert_equal true, collation.deterministic
  end

  def test_collation_definitions_with_no_collations
    @connection.execute "DROP COLLATION german"
    assert_equal [], @connection.collation_definitions
  end

  def test_collation_definitions_with_case_insensitive
    @connection.execute <<~SQL
      CREATE COLLATION case_insensitive
        (provider = icu, locale = 'und-u-ks-level2', deterministic = false)
    SQL

    assert_equal 2, @connection.collation_definitions.length
    assert collation = @connection.collation_definitions.find { |c| c.name == "case_insensitive" }

    assert_equal "icu", collation.provider
    assert_equal "und-u-ks-level2", collation.lc_collate
    assert_equal "und-u-ks-level2", collation.lc_ctype
    assert_equal false, collation.deterministic
  end

  def test_create_collation_for_japanese
    assert_difference -> { @connection.collations.length } do
      @connection.create_collation "japanese", provider: "libc", locale: "ja_JP"
    end

    assert collation = @connection.collation_definitions.find { |c| c.name == "japanese" }

    assert_equal "libc", collation.provider
    assert_equal "ja_JP", collation.lc_collate
    assert_equal "ja_JP", collation.lc_ctype
    assert_equal true, collation.deterministic
  end

  def test_create_collation_for_case_insensitive
    assert_difference -> { @connection.collations.length } do
      @connection.create_collation "case_insensitive",
        provider: "icu", locale: "und-u-ks-level2", deterministic: false
    end

    assert collation = @connection.collation_definitions.find { |c| c.name == "case_insensitive" }

    assert_equal "icu", collation.provider
    assert_equal "und-u-ks-level2", collation.lc_collate
    assert_equal "und-u-ks-level2", collation.lc_ctype
    assert_equal false, collation.deterministic
  end

  def test_create_collation_when_collation_already_exists
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"

    assert_no_difference -> { @connection.collations.length } do
      @connection.create_collation "japanese", provider: "libc", locale: "ja_JP"
    end
  end

  def test_create_collation_with_lc_collate_and_lc_ctype_params
    assert_difference -> { @connection.collations.length } do
      @connection.create_collation "japanese",
        provider: "libc", lc_collate: "ja_JP", lc_ctype: "ja_JP"
    end

    assert collation = @connection.collation_definitions.find { |c| c.name == "japanese" }

    assert_equal "libc", collation.provider
    assert_equal "ja_JP", collation.lc_collate
    assert_equal "ja_JP", collation.lc_ctype
    assert_equal true, collation.deterministic
  end

  def test_create_collation_with_duplicate_locale_params
    error = assert_raises ArgumentError do
      @connection.create_collation "japanese",
        provider: "libc", locale: "ja_JP", lc_collate: "ja_JP", lc_ctype: "ja_JP"
    end

    assert_equal LOCALE_ERROR_MESSAGE, error.message
  end

  def test_create_collation_with_no_locale_params
    error = assert_raises ArgumentError do
      @connection.create_collation "japanese", provider: "libc"
    end

    assert_equal LOCALE_ERROR_MESSAGE, error.message
  end

  def test_drop_collation_for_japanese
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"

    assert_difference -> { @connection.collations.length }, -1 do
      @connection.drop_collation "japanese", provider: "libc", locale: "ja_JP"
    end

    assert_not @connection.collation_definitions.find { |c| c.name == "japanese" }
  end

  def test_drop_collation_when_collation_does_not_exist
    assert_no_difference -> { @connection.collations.length } do
      @connection.drop_collation "japanese", provider: "libc", locale: "ja_JP"
    end
  end

  def test_drop_collation_with_lc_collate_and_lc_ctype_params
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"

    assert_difference -> { @connection.collations.length }, -1 do
      @connection.drop_collation "japanese",
        provider: "libc", lc_collate: "ja_JP", lc_ctype: "ja_JP"
    end

    assert_not @connection.collation_definitions.find { |c| c.name == "japanese" }
  end

  def test_drop_collation_ignores_param_values
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"

    assert_difference -> { @connection.collations.length }, -1 do
      @connection.drop_collation "japanese", provider: "foo", locale: "foo_BAR"
    end

    assert_not @connection.collation_definitions.find { |c| c.name == "japanese" }
  end

  def test_drop_collation_with_duplicate_locale_params
    error = assert_raises ArgumentError do
      @connection.drop_collation "japanese",
        provider: "libc", locale: "ja_JP", lc_collate: "ja_JP", lc_ctype: "ja_JP"
    end

    assert_equal LOCALE_ERROR_MESSAGE, error.message
  end

  def test_drop_collation_with_no_locale_params
    error = assert_raises ArgumentError do
      @connection.drop_collation "japanese", provider: "libc"
    end

    assert_equal LOCALE_ERROR_MESSAGE, error.message
  end
end
