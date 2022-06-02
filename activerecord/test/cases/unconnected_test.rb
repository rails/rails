# frozen_string_literal: true

require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestUnconnectedAdapter < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @underlying = ActiveRecord::Base.connection
    @specification = ActiveRecord::Base.remove_connection

    # Clear out connection info from other pids (like a fork parent) too
    ActiveRecord::ConnectionAdapters::PoolConfig.discard_pools!
  end

  teardown do
    @underlying = nil
    ActiveRecord::Base.establish_connection(@specification)
    load_schema if in_memory_db?
  end

  def test_connection_no_longer_established
    assert_raise(ActiveRecord::ConnectionNotEstablished) do
      TestRecord.find(1)
    end

    assert_raise(ActiveRecord::ConnectionNotEstablished) do
      TestRecord.new.save
    end
  end

  def test_error_message_when_connection_not_established
    error = assert_raise(ActiveRecord::ConnectionNotEstablished) do
      TestRecord.find(1)
    end

    assert_equal "No connection pool for 'ActiveRecord::Base' found.", error.message
  end

  def test_underlying_adapter_no_longer_active
    assert_not @underlying.active?, "Removed adapter should no longer be active"
  end
end
