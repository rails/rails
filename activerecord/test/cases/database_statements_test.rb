require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  unless current_adapter?(:OracleAdapter)
    def test_exec_insert
      result = @connection.exec_insert("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)", nil, [])
      assert_not_nil @connection.send(:last_inserted_id, result)
    end
  end

  def test_insert_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :insert)
  end

  def test_create_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :create)
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
