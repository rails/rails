# frozen_string_literal: true

require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def test_exec_insert
    intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(raw_sql: "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)", name: nil, binds: [])
    result = @connection.exec_insert(intent)
    assert_not_nil @connection.send(:last_inserted_id, result)
  end

  def test_insert_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :insert)
  end

  def test_create_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :create)
  end

  private
    def return_the_inserted_id(method:)
      @connection.send(method, "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
    end
end
