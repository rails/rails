# frozen_string_literal: true

require "cases/helper"

class PostgreSQLCaseSensitivityTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
    enable_extension!("citext", @connection)
    @connection.create_table :pg_case_test, force: true do |t|
      t.string :plain_string
      t.citext :ci_text_col
    end
  end

  def teardown
    @connection.drop_table :pg_case_test, if_exists: true
    disable_extension!("citext", @connection)
  end

  test "case_sensitive? returns true for plain string column" do
    column = @connection.columns(:pg_case_test).find { |c| c.name == "plain_string" }
    assert_predicate column, :case_sensitive?
  end

  test "case_sensitive? returns false for citext column" do
    column = @connection.columns(:pg_case_test).find { |c| c.name == "ci_text_col" }
    assert_not_predicate column, :case_sensitive?
  end
end
