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

  test ".log_to_stdout switches logging to stdout" do
    original_logger = ActiveRecord::Base.logger

    assert_not ActiveSupport::Logger.logger_outputs_to?(ActiveRecord::Base.logger, STDOUT)

    ActiveRecord.log_to_stdout

    assert ActiveSupport::Logger.logger_outputs_to?(ActiveRecord::Base.logger, STDOUT)
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  test ".log_to_stdout called with block switches logging to stdout for the duration of the block" do
    assert_not ActiveSupport::Logger.logger_outputs_to?(ActiveRecord::Base.logger, STDOUT)

    ActiveRecord.log_to_stdout do
      assert ActiveSupport::Logger.logger_outputs_to?(ActiveRecord::Base.logger, STDOUT)
    end

    assert_not ActiveSupport::Logger.logger_outputs_to?(ActiveRecord::Base.logger, STDOUT)
  end
end
