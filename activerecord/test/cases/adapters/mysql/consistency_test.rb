require "cases/helper"

class MysqlConsistencyTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  class Consistency < ActiveRecord::Base
    self.table_name = "mysql_consistency"
  end

  setup do
    @old_emulate_booleans = ActiveRecord::ConnectionAdapters::MysqlAdapter.emulate_booleans
    ActiveRecord::ConnectionAdapters::MysqlAdapter.emulate_booleans = false

    @connection = ActiveRecord::Base.connection
    @connection.clear_cache!
    @connection.create_table("mysql_consistency") do |t|
      t.boolean "a_bool"
      t.string "a_string"
    end
    Consistency.reset_column_information
    Consistency.create!
  end

  teardown do
    ActiveRecord::ConnectionAdapters::MysqlAdapter.emulate_booleans = @old_emulate_booleans
    @connection.drop_table "mysql_consistency"
  end

  test "boolean columns with random value type cast to 0 when emulate_booleans is false" do
    with_new = Consistency.new
    with_last = Consistency.last
    with_new.a_bool = 'wibble'
    with_last.a_bool = 'wibble'

    assert_equal 0, with_new.a_bool
    assert_equal 0, with_last.a_bool
  end

  test "string columns call #to_s" do
    with_new = Consistency.new
    with_last = Consistency.last
    thing = Object.new
    with_new.a_string = thing
    with_last.a_string = thing

    assert_equal thing.to_s, with_new.a_string
    assert_equal thing.to_s, with_last.a_string
  end
end
