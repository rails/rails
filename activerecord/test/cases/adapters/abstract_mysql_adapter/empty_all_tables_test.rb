# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/author"
require "models/bulb"
require "models/car"

class MySQLEmptyTablesTest < ActiveRecord::AbstractMysqlTestCase
  self.use_transactional_tests = false

  def setup
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_empty_all_tables_uses_delete_not_truncate
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      queries << event.payload[:sql] if event.payload[:name] == "Delete Tables"
    end

    @conn.empty_all_tables

    ActiveSupport::Notifications.unsubscribe(subscriber)

    assert queries.any? { |q| q.include?("DELETE FROM") }, "Expected DELETE statements to be used"
    assert queries.none? { |q| q.include?("TRUNCATE") }, "Expected TRUNCATE statements to NOT be used"
  end
end
