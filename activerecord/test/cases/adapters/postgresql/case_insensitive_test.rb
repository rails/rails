# frozen_string_literal: true

require "cases/helper"

class PostgresqlCaseInsensitiveTest < ActiveRecord::PostgreSQLTestCase
  class Default < ActiveRecord::Base; end

  def test_case_insensitiveness
    connection = ActiveRecord::Base.lease_connection

    attr = Default.arel_table[:char1]
    comparison = connection.case_insensitive_comparison(attr, nil)
    assert_match(/lower/i, comparison.to_sql)

    attr = Default.arel_table[:char2]
    comparison = connection.case_insensitive_comparison(attr, nil)
    assert_match(/lower/i, comparison.to_sql)

    attr = Default.arel_table[:char3]
    comparison = connection.case_insensitive_comparison(attr, nil)
    assert_match(/lower/i, comparison.to_sql)

    attr = Default.arel_table[:multiline_default]
    comparison = connection.case_insensitive_comparison(attr, nil)
    assert_match(/lower/i, comparison.to_sql)
  end
end
