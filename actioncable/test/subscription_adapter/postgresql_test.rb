require "test_helper"
require_relative "./common"

require "active_record"

class PostgresqlAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def setup
    database_config = { "adapter" => "postgresql", "database" => "activerecord_unittest" }
    ar_tests = File.expand_path("../../../activerecord/test", __dir__)
    if Dir.exist?(ar_tests)
      require File.join(ar_tests, "config")
      require File.join(ar_tests, "support/config")
      local_config = ARTest.config["arunit"]
      database_config.update local_config if local_config
    end

    ActiveRecord::Base.establish_connection database_config

    begin
      ActiveRecord::Base.connection
    rescue
      @rx_adapter = @tx_adapter = nil
      skip "Couldn't connect to PostgreSQL: #{database_config.inspect}"
    end

    super
  end

  def teardown
    super

    ActiveRecord::Base.clear_all_connections!
  end

  def test_raises_if_connection_is_not_pg_connection
    bad_adapter = Class.new(ActionCable::SubscriptionAdapter::PostgreSQL) do
      def fetch_connection
        yield Object.new
      end
    end

    e = assert_raises(RuntimeError) do
      bad_adapter.new(ActionCable::Server::Base.new).with_connection
    end

    assert_match(/PostgreSQL adapter only supports the use of PG::Connection/, e.message)
  end

  def cable_config
    { adapter: "postgresql" }
  end
end
