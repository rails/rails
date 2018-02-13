# frozen_string_literal: true

require "cases/helper"

class PostgresqlCaseInsensitiveTest < ActiveRecord::PostgreSQLTestCase
  class Default < ActiveRecord::Base; end

  def test_case_insensitiveness
    connection = ActiveRecord::Base.connection
    table = Default.arel_table

    column = Default.columns_hash["char1"]
    comparison = connection.case_insensitive_comparison table, :char1, column, nil
    assert_match(/lower/i, comparison.to_sql)

    column = Default.columns_hash["char2"]
    comparison = connection.case_insensitive_comparison table, :char2, column, nil
    assert_match(/lower/i, comparison.to_sql)

    column = Default.columns_hash["char3"]
    comparison = connection.case_insensitive_comparison table, :char3, column, nil
    assert_match(/lower/i, comparison.to_sql)

    column = Default.columns_hash["multiline_default"]
    comparison = connection.case_insensitive_comparison table, :multiline_default, column, nil
    assert_match(/lower/i, comparison.to_sql)
  end
end
