require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_insert_should_return_the_inserted_id
    id = @connection.insert("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
    assert_not_nil id
  end
end
