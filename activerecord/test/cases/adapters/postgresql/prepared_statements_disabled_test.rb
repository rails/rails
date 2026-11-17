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
    assert_not Developer.lease_connection.prepared_statements

    david = developers(:david)

    assert_equal david, Developer.where(name: "David").last # With Binds
    assert_operator Developer.count, :>, 0 # Without Binds
  end

  def test_statement_cache_queries_do_not_prepare_when_prepared_statements_are_disabled
    assert_not Developer.lease_connection.prepared_statements

    david = developers(:david)

    statement_names = capture_statement_names do
      assert_equal david, Developer.find(david.id)
      assert_equal david, Developer.find_by(name: "David")
    end

    assert_empty statement_names
  end

  private
    def capture_statement_names
      names = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        names << payload[:statement_name] if payload[:statement_name]
      end
      yield
      names
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
