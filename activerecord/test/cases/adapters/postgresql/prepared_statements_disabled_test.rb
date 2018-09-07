# frozen_string_literal: true

require "cases/helper"
require "models/computer"
require "models/developer"

class PreparedStatementsDisabledTest < ActiveRecord::PostgreSQLTestCase
  fixtures :developers

  def setup
    @conn = ActiveRecord::Base.establish_connection :arunit_without_prepared_statements
  end

  def teardown
    @conn.release_connection
    ActiveRecord::Base.establish_connection :arunit
  end

  def test_select_query_works_even_when_prepared_statements_are_disabled
    assert_not Developer.connection.prepared_statements

    david = developers(:david)

    assert_equal david, Developer.where(name: "David").last # With Binds
    assert_operator Developer.count, :>, 0 # Without Binds
  end
end
