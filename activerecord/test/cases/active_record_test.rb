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
end
