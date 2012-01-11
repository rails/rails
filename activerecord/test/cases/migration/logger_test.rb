require "cases/helper"

module ActiveRecord
  class Migration
    class LoggerTest < ActiveRecord::TestCase
      def test_migration_should_be_run_without_logger
        previous_logger = ActiveRecord::Base.logger
        ActiveRecord::Base.logger = nil
        assert_nothing_raised do
          ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid")
        end
      ensure
        ActiveRecord::Base.logger = previous_logger
      end
    end
  end
end
