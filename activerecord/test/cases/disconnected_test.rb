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
      main_connection = main_ractor_connection(@connection)
      first_connection = main_connection.instance_variable_get(:@raw_connection).__id__

      @connection.disconnect!
      assert_not_predicate main_connection, :connected?

      @connection.execute "SELECT count(*) from products"
      second_connection = main_connection.instance_variable_get(:@raw_connection).__id__

      assert_not_equal second_connection, first_connection
    end
  end
end
