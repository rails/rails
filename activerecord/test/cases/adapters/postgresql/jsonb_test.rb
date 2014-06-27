# encoding: utf-8

require_relative 'json_test'

class PostgresqlJSONBTest < PostgresqlJSONTest
  # Use jsonb instead of json
  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('json_data_type') do |t|
          t.jsonb 'payload'#, :default => {}
          t.jsonb 'settings'
        end
      end
    rescue ActiveRecord::StatementInvalid => e
      skip "do not test on PG without jsonb (#{e.to_s})"
    end
    @column = JsonDataType.columns_hash['payload']
  end

  def test_column
    column = JsonDataType.columns_hash["payload"]
    assert_equal :jsonb, column.type
    assert_equal "jsonb", column.sql_type
    assert_not column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end
end
