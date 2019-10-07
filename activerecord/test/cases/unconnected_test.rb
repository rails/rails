# frozen_string_literal: true

require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestUnconnectedAdapter < ActiveRecord::TestCase
  self.use_transactional_tests = false
  include ActiveSupport::Testing::Isolation

  def setup
    @underlying = ActiveRecord::Base.connection
    @role = ActiveRecord::Base.connection_handler.remove_connection(:writing)

    # Clear out connection info from other pids (like a fork parent) too
    ActiveRecord::ConnectionAdapters::Role.discard_pools!
  end

  teardown do
    @underlying = nil
    ActiveRecord::Base.connection_handler.establish_connection(@role, role: :writing)
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

    assert_equal "No connection pool for 'writing' role found.", error.message
  end

  def test_underlying_adapter_no_longer_active
    assert_not @underlying.active?, "Removed adapter should no longer be active"
  end
end
