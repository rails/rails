require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_insert_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :insert)
  end

  def test_create_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :create)
  end

  def test_insert_update_delete_sql_is_deprecated
    assert_deprecated { @connection.insert_sql("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)") }
    assert_deprecated { @connection.update_sql("UPDATE accounts SET credit_limit = 6000 WHERE firm_id = 42") }
    assert_deprecated { @connection.delete_sql("DELETE FROM accounts WHERE firm_id = 42") }
  end

  private

    def return_the_inserted_id(method:)
      # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
      if current_adapter?(:OracleAdapter)
        sequence_name = "accounts_seq"
        id_value = @connection.next_sequence_value(sequence_name)
        @connection.send(method, "INSERT INTO accounts (id, firm_id,credit_limit) VALUES (accounts_seq.nextval,42,5000)", nil, :id, id_value, sequence_name)
      else
        @connection.send(method, "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
      end
    end
end
