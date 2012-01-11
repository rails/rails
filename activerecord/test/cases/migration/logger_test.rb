require "cases/helper"

module ActiveRecord
  class Migration
    class LoggerTest < ActiveRecord::TestCase
      Migration = Struct.new(:version) do
        def migrate direction
          # do nothing
        end
      end

      def test_migration_should_be_run_without_logger
        previous_logger = ActiveRecord::Base.logger
        ActiveRecord::Base.logger = nil
        migrations = [Migration.new(1), Migration.new(2), Migration.new(3)]
        ActiveRecord::Migrator.new(:up, migrations).migrate
      ensure
        ActiveRecord::Base.logger = previous_logger
      end
    end
  end
end
