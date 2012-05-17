require "cases/helper"
require 'models/person'

class MysqlCaseSensitivityTest < ActiveRecord::TestCase
  class CollationTest < ActiveRecord::Base
    validates_uniqueness_of :string_cs_column, :case_sensitive => false
    validates_uniqueness_of :string_ci_column, :case_sensitive => false
  end

  def test_columns_include_collation_different_from_table
    assert_equal 'utf8_bin', CollationTest.columns_hash['string_cs_column'].collation
    assert_equal 'utf8_general_ci', CollationTest.columns_hash['string_ci_column'].collation
  end

  def test_case_sensitive
    assert !CollationTest.columns_hash['string_ci_column'].case_sensitive?
    assert CollationTest.columns_hash['string_cs_column'].case_sensitive?
  end

  def test_case_insensitive_comparison_for_ci_column
    CollationTest.create!(:string_ci_column => 'A')
    invalid = CollationTest.new(:string_ci_column => 'a')
    queries = assert_sql { invalid.save }
    ci_uniqueness_query = queries.detect { |q| q.match(/string_ci_column/) }
    assert_no_match(/lower/i, ci_uniqueness_query)
  end

  def test_case_insensitive_comparison_for_cs_column
    CollationTest.create!(:string_cs_column => 'A')
    invalid = CollationTest.new(:string_cs_column => 'a')
    queries = assert_sql { invalid.save }
    cs_uniqueness_query = queries.detect { |q| q.match(/string_cs_column/) }
    assert_match(/lower/i, cs_uniqueness_query)
  end
end
