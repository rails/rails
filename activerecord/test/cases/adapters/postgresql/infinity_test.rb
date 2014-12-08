require "cases/helper"

class PostgresqlInfinityTest < ActiveRecord::TestCase
  class PostgresqlInfinity < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:postgresql_infinities) do |t|
      t.float :float
      t.datetime :datetime
    end
  end

  teardown do
    @connection.execute("DROP TABLE IF EXISTS postgresql_infinities")
  end

  test "type casting infinity on a float column" do
    record = PostgresqlInfinity.create!(float: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.float
  end

  test "update_all with infinity on a float column" do
    record = PostgresqlInfinity.create!
    PostgresqlInfinity.update_all(float: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.float
  end

  test "type casting infinity on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.datetime
  end

  test "update_all with infinity on a datetime column" do
    record = PostgresqlInfinity.create!
    PostgresqlInfinity.update_all(datetime: Float::INFINITY)
    record.reload
    assert_equal Float::INFINITY, record.datetime
  end

  test "assigning 'infinity' on a datetime column" do
    record = PostgresqlInfinity.create!(datetime: "infinity")
    assert_equal Float::INFINITY, record.datetime
    assert_equal record.datetime, record.reload.datetime
  end
end
