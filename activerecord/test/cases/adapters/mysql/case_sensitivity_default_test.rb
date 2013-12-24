require "cases/helper"
require 'models/person'

class MysqlCaseSensitivityDefaultTest < ActiveRecord::TestCase
  class CollationTest < ActiveRecord::Base
    validates_uniqueness_of :string_cs_column
    validates_uniqueness_of :string_ci_column
  end

  def teardown
    CollationTest.delete_all
  end

  def test_default_comparison_for_ci_column
    CollationTest.create!(:string_ci_column => 'A',
                          :string_cs_column => 'b')
    invalid = CollationTest.new(:string_ci_column => 'a',
                                :string_cs_column => 'c')
    queries = assert_sql { invalid.save }
    assert_equal(["has already been taken"], invalid.errors[:string_ci_column])
    ci_uniqueness_query = queries.detect { |q| q.match(/string_ci_column/) }
    assert_no_match(/binary/i, ci_uniqueness_query)
  end

  def test_default_comparison_for_cs_column
    CollationTest.create!(:string_cs_column => 'A',
                          :string_ci_column => 'b')
    invalid = CollationTest.new(:string_cs_column => 'a',
                                :string_ci_column => 'c')
    queries = assert_sql { invalid.save }
    assert_equal([], invalid.errors[:string_cs_column])
    cs_uniqueness_query = queries.detect { |q| q.match(/string_cs_column/)}
    assert_no_match(/lower/i, cs_uniqueness_query)
  end
end
