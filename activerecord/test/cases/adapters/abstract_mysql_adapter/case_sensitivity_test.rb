# frozen_string_literal: true

require "cases/helper"

class CaseSensitivityTest < ActiveRecord::AbstractMysqlTestCase
  class CollationTest < ActiveRecord::Base
  end

  repair_validations(CollationTest)

  def test_columns_include_collation_different_from_table
    assert_equal "utf8mb4_bin", CollationTest.columns_hash["string_cs_column"].collation
    assert_equal "utf8mb4_general_ci", CollationTest.columns_hash["string_ci_column"].collation
  end

  def test_case_sensitive
    assert_not_predicate CollationTest.columns_hash["string_ci_column"], :case_sensitive?
    assert_predicate CollationTest.columns_hash["string_cs_column"], :case_sensitive?
  end

  def test_case_insensitive_comparison_for_ci_column
    CollationTest.validates_uniqueness_of(:string_ci_column, case_sensitive: false)
    CollationTest.create!(string_ci_column: "A")
    invalid = CollationTest.new(string_ci_column: "a")
    queries = capture_sql { invalid.save }
    ci_uniqueness_query = queries.detect { |q| q.match(/string_ci_column/) }
    assert_no_match(/lower/i, ci_uniqueness_query)
  end

  def test_case_insensitive_comparison_for_cs_column
    CollationTest.validates_uniqueness_of(:string_cs_column, case_sensitive: false)
    CollationTest.create!(string_cs_column: "A")
    invalid = CollationTest.new(string_cs_column: "a")
    queries = capture_sql { invalid.save }
    cs_uniqueness_query = queries.detect { |q| q.match(/string_cs_column/) }
    assert_match(/lower/i, cs_uniqueness_query)
  end

  def test_case_sensitive_comparison_for_ci_column
    CollationTest.validates_uniqueness_of(:string_ci_column, case_sensitive: true)
    CollationTest.create!(string_ci_column: "A")
    invalid = CollationTest.new(string_ci_column: "A")
    queries = capture_sql { invalid.save }
    ci_uniqueness_query = queries.detect { |q| q.match(/string_ci_column/) }
    assert_match(/binary/i, ci_uniqueness_query)
  end

  def test_case_sensitive_comparison_for_cs_column
    CollationTest.validates_uniqueness_of(:string_cs_column, case_sensitive: true)
    CollationTest.create!(string_cs_column: "A")
    invalid = CollationTest.new(string_cs_column: "A")
    queries = capture_sql { invalid.save }
    cs_uniqueness_query = queries.detect { |q| q.match(/string_cs_column/) }
    assert_no_match(/binary/i, cs_uniqueness_query)
  end

  def test_case_sensitive_comparison_for_binary_column
    CollationTest.validates_uniqueness_of(:binary_column, case_sensitive: true)
    CollationTest.create!(binary_column: "A")
    invalid = CollationTest.new(binary_column: "A")
    queries = capture_sql { invalid.save }
    bin_uniqueness_query = queries.detect { |q| q.match(/binary_column/) }
    assert_no_match(/\bBINARY\b/, bin_uniqueness_query)
  end
end
