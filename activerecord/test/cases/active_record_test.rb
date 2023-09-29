# frozen_string_literal: true

require "cases/helper"
require "rack"

class ActiveRecordTest < ActiveRecord::TestCase
  unless in_memory_db?
    test ".disconnect_all! closes all connections" do
      ActiveRecord::Base.connection.active?
      assert_predicate ActiveRecord::Base, :connected?

      ActiveRecord.disconnect_all!
      assert_not_predicate ActiveRecord::Base, :connected?

      ActiveRecord::Base.connection.connect!
      assert_predicate ActiveRecord::Base, :connected?
    end
  end
end
