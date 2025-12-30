# frozen_string_literal: true

require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestDisconnectedAdapter < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  teardown do
    return if in_memory_db?
  end

  unless in_memory_db?
    test "reconnects to execute statements when disconnected" do
      @connection.execute "SELECT count(*) from products"
      first_connection = @connection.instance_variable_get(:@raw_connection).__id__

      @connection.disconnect!
      assert_nil @connection.instance_variable_get(:@raw_connection)

      @connection.execute "SELECT count(*) from products"
      second_connection = @connection.instance_variable_get(:@raw_connection).__id__

      assert_not_equal second_connection, first_connection
    end
  end
end
