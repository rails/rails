# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class LoggerTest < ActiveRecord::TestCase
      # MySQL can't roll back ddl changes
      self.use_transactional_tests = false

      Migration = Struct.new(:name, :version) do
        def disable_ddl_transaction; false end
        def migrate(direction)
          # do nothing
        end
      end

      def setup
        super
        @schema_migration = ActiveRecord::Base.connection.schema_migration
        @schema_migration.create_table
        @schema_migration.delete_all_versions
        @internal_metadata = ActiveRecord::Base.connection.internal_metadata
      end

      teardown do
        @schema_migration.drop_table
      end

      def test_migration_should_be_run_without_logger
        previous_logger = ActiveRecord::Base.logger
        ActiveRecord::Base.logger = nil
        migrations = [Migration.new("a", 1), Migration.new("b", 2), Migration.new("c", 3)]
        ActiveRecord::Migrator.new(:up, migrations, @schema_migration, @internal_metadata).migrate
      ensure
        ActiveRecord::Base.logger = previous_logger
      end
    end
  end
end
