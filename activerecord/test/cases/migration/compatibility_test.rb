require "cases/helper"

module ActiveRecord
  class Migration
    class CompatibilityTest < ActiveRecord::TestCase
      attr_reader :connection
      self.use_transactional_tests = false

      def setup
        super
        @connection = ActiveRecord::Base.connection
        @verbose_was = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = false

        connection.create_table :testings do |t|
          t.column :foo, :string, limit: 100
          t.column :bar, :string, limit: 100
        end
      end

      teardown do
        connection.drop_table :testings rescue nil
        ActiveRecord::Migration.verbose = @verbose_was
        ActiveRecord::SchemaMigration.delete_all rescue nil
      end

      def test_migration_doesnt_remove_named_index
        connection.add_index :testings, :foo, name: "custom_index_name"

        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def version; 101 end
          def migrate(x)
            remove_index :testings, :foo
          end
        }.new

        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
        assert_raise(StandardError) { ActiveRecord::Migrator.new(:up, [migration]).migrate }
        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
      end

      def test_migration_does_remove_unnamed_index
        connection.add_index :testings, :bar

        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def version; 101 end
          def migrate(x)
            remove_index :testings, :bar
          end
        }.new

        assert connection.index_exists?(:testings, :bar)
        ActiveRecord::Migrator.new(:up, [migration]).migrate
        assert_not connection.index_exists?(:testings, :bar)
      end

      def test_references_does_not_add_index_by_default
        migration = Class.new(ActiveRecord::Migration) {
          def migrate(x)
            create_table :more_testings do |t|
              t.references :foo
              t.belongs_to :bar, index: false
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration]).migrate

        assert_not connection.index_exists?(:more_testings, :foo_id)
        assert_not connection.index_exists?(:more_testings, :bar_id)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_timestamps_have_null_constraints_if_not_present_in_migration_of_create_table
        migration = Class.new(ActiveRecord::Migration) {
          def migrate(x)
            create_table :more_testings do |t|
              t.timestamps
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration]).migrate

        assert connection.columns(:more_testings).find { |c| c.name == "created_at" }.null
        assert connection.columns(:more_testings).find { |c| c.name == "updated_at" }.null
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_timestamps_have_null_constraints_if_not_present_in_migration_for_adding_timestamps_to_existing_table
        migration = Class.new(ActiveRecord::Migration) {
          def migrate(x)
            add_timestamps :testings
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration]).migrate

        assert connection.columns(:testings).find { |c| c.name == "created_at" }.null
        assert connection.columns(:testings).find { |c| c.name == "updated_at" }.null
      end

      def test_legacy_migrations_get_deprecation_warning_when_run
        migration = Class.new(ActiveRecord::Migration) {
          def up
            add_column :testings, :baz, :string
          end
        }

        assert_deprecated do
          migration.migrate :up
        end
      end
    end
  end
end
