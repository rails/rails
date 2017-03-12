require "cases/helper"

class Mysql2TimestampTest < ActiveRecord::Mysql2TestCase
  class MysqlTimestamp < ActiveRecord::Base
  end

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table :mysql_timestamps, force: true do |t|
      t.timestamp :time
    end
    @time = Time.now.utc.change(usec: 0)
    MysqlTimestamp.create!(id: 1, time: @time)
  end

  def teardown
    @connection.drop_table :mysql_timestamps, if_exists: true
  end

  def test_timestamp_with_time_zone_utc
    with_timezone_config default: :utc do
      @connection.reconnect!

      timestamp = MysqlTimestamp.find(1)
      assert_equal @time, timestamp.time
    end
  ensure
    @connection.reconnect!
  end

  def test_timestamp_with_time_zone_local
    with_timezone_config default: :local do
      with_env_tz "America/New_York" do
        @connection.reconnect!

        timestamp = MysqlTimestamp.find(1)
        assert_equal @time, timestamp.time
      end
    end
  ensure
    @connection.reconnect!
  end

  def test_create_timestamp_with_time_zone_local
    timestamp = nil

    with_timezone_config default: :local do
      with_env_tz "America/New_York" do
        @connection.reconnect!

        timestamp = MysqlTimestamp.create!(id: 2, time: @time)
        timestamp.reload
        assert_equal @time, timestamp.time
      end
    end

    @connection.reconnect!

    timestamp.reload
    assert_equal @time, timestamp.time
  ensure
    @connection.reconnect!
  end
end
