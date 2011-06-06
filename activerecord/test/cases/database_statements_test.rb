require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_insert_should_return_the_inserted_id
    # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
    if current_adapter?(:OracleAdapter)
      sequence_name = "accounts_seq"
      id_value = @connection.next_sequence_value(sequence_name)
      id = @connection.insert("INSERT INTO accounts (id, firm_id,credit_limit) VALUES (accounts_seq.nextval,42,5000)", nil, :id, id_value, sequence_name)
    else
      id = @connection.insert("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
    end
    assert_not_nil id
  end
end
