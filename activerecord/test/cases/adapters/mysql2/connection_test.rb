require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  def setup
    super
    @connection = ActiveRecord::Base.connection
  end

  def test_no_automatic_reconnection_after_timeout
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    assert !@connection.active?
  end

  def test_successful_reconnection_after_timeout_with_manual_reconnect
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.reconnect!
    assert @connection.active?
  end

  def test_successful_reconnection_after_timeout_with_verify
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.verify!
    assert @connection.active?
  end

  def test_time_zone_connection_configuration_option
    connection_options = ActiveRecord::Base.configurations['arunit']
    time_zones = ['Australia/Sydney', 'Europe/Prague']
    run_without_connection do
      # Set different time zones and expect different results.
      time_zones.each do |time_zone|
        ActiveRecord::Base.establish_connection(connection_options.merge({:time_zone => time_zone}))
        result = ActiveRecord::Base.connection.execute("SELECT @@session.time_zone")
        assert_equal(result.first.first, time_zone)
      end
    end
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end
end
