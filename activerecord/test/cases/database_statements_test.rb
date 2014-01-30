require "cases/helper"
require 'minitest/mock'

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


  def test_to_sql_should_not_raise_exception_for_nil_binds_param
    class_mock = MiniTest::Mock.new
    class_mock.expect(:name, MiniTest::Mock, [])
    statement_mock = MiniTest::Mock.new
    statement_mock.expect(:to_matcher, nil, [])
    statement_mock.expect(:class, class_mock, [])
    arel_mock = MiniTest::Mock.new
    arel_mock.expect(:ast, statement_mock, [])
    @connection.to_sql(arel_mock)
  end

end
