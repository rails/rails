require "cases/helper"

module ActiveRecord
  class Migration
    class LoggerTest < ActiveRecord::TestCase
      # MySQL can't roll back ddl changes
      self.use_transactional_tests = false

      Migration = Struct.new(:name, :version) do
        def disable_ddl_transaction; false end
        def migrate direction
          # do nothing
        end
      end

      def setup
        super
        ActiveRecord::SchemaMigration.create_table
        ActiveRecord::SchemaMigration.delete_all
      end

      teardown do
        ActiveRecord::SchemaMigration.drop_table
      end

      def test_migration_should_be_run_without_logger
        previous_logger = ActiveRecord::Base.logger
        ActiveRecord::Base.logger = nil
        migrations = [Migration.new("a", 1), Migration.new("b", 2), Migration.new("c", 3)]
        ActiveRecord::Migrator.new(:up, migrations).migrate
      ensure
        ActiveRecord::Base.logger = previous_logger
      end
    end
  end
end
