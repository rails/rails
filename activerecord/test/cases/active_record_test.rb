# frozen_string_literal: true

require "cases/helper"

class ActiveRecordTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  unless in_memory_db?
    test ".disconnect_all! closes all connections" do
      ActiveRecord::Base.lease_connection.connect!
      assert_predicate ActiveRecord::Base, :connected?

      ActiveRecord.disconnect_all!
      assert_not_predicate ActiveRecord::Base, :connected?

      ActiveRecord::Base.lease_connection.connect!
      assert_predicate ActiveRecord::Base, :connected?
    end
  end

  test ".database_cli= is deprecated" do
    @before_database_cli = ActiveRecord.database_cli
    msg = <<~MSG.squish
      ActiveRecord.database_cli is deprecated and will be removed in Rails 8.1.
      Use `dbconsole_command` on the database config instead.
    MSG
    assert_deprecated(msg, ActiveRecord.deprecator) do
      ActiveRecord.database_cli = "foo"
    end
  ensure
    assert_deprecated(ActiveRecord.deprecator) do
      ActiveRecord.database_cli = @before_database_cli
    end
  end
end
