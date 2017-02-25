require "cases/helper"
require "support/schema_dumping_helper"

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
        migration = Class.new(ActiveRecord::Migration[4.2]) {
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
        migration = Class.new(ActiveRecord::Migration[4.2]) {
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
        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def migrate(x)
            add_timestamps :testings
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration]).migrate

        assert connection.columns(:testings).find { |c| c.name == "created_at" }.null
        assert connection.columns(:testings).find { |c| c.name == "updated_at" }.null
      end

      def test_legacy_migrations_raises_exception_when_inherited
        e = assert_raises(StandardError) do
          class_eval("class LegacyMigration < ActiveRecord::Migration; end")
        end
        assert_match(/LegacyMigration < ActiveRecord::Migration\[4\.2\]/, e.message)
      end
    end
  end
end

class LegacyPrimaryKeyTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  class LegacyPrimaryKey < ActiveRecord::Base
  end

  def setup
    @migration = nil
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    @migration.migrate(:down) if @migration
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::SchemaMigration.delete_all rescue nil
    LegacyPrimaryKey.reset_column_information
  end

  def test_legacy_primary_key_should_be_auto_incremented
    @migration = Class.new(ActiveRecord::Migration[5.0]) {
      def change
        create_table :legacy_primary_keys do |t|
          t.references :legacy_ref
        end
      end
    }.new

    @migration.migrate(:up)

    legacy_pk = LegacyPrimaryKey.columns_hash["id"]
    assert_not legacy_pk.bigint?
    assert_not legacy_pk.null

    legacy_ref = LegacyPrimaryKey.columns_hash["legacy_ref_id"]
    assert_not legacy_ref.bigint?

    record1 = LegacyPrimaryKey.create!
    assert_not_nil record1.id

    record1.destroy

    record2 = LegacyPrimaryKey.create!
    assert_not_nil record2.id
    assert_operator record2.id, :>, record1.id
  end

  def test_legacy_integer_primary_key_should_not_be_auto_incremented
    skip if current_adapter?(:SQLite3Adapter)

    @migration = Class.new(ActiveRecord::Migration[5.0]) {
      def change
        create_table :legacy_primary_keys, id: :integer do |t|
        end
      end
    }.new

    @migration.migrate(:up)

    assert_raises(ActiveRecord::NotNullViolation) do
      LegacyPrimaryKey.create!
    end

    schema = dump_table_schema "legacy_primary_keys"
    assert_match %r{create_table "legacy_primary_keys", id: :integer, default: nil}, schema
  end

  if current_adapter?(:Mysql2Adapter)
    def test_legacy_bigint_primary_key_should_be_auto_incremented
      @migration = Class.new(ActiveRecord::Migration[5.0]) {
        def change
          create_table :legacy_primary_keys, id: :bigint
        end
      }.new

      @migration.migrate(:up)

      legacy_pk = LegacyPrimaryKey.columns_hash["id"]
      assert legacy_pk.bigint?
      assert legacy_pk.auto_increment?

      schema = dump_table_schema "legacy_primary_keys"
      assert_match %r{create_table "legacy_primary_keys", (?!id: :bigint, default: nil)}, schema
    end
  else
    def test_legacy_bigint_primary_key_should_not_be_auto_incremented
      @migration = Class.new(ActiveRecord::Migration[5.0]) {
        def change
          create_table :legacy_primary_keys, id: :bigint do |t|
          end
        end
      }.new

      @migration.migrate(:up)

      assert_raises(ActiveRecord::NotNullViolation) do
        LegacyPrimaryKey.create!
      end

      schema = dump_table_schema "legacy_primary_keys"
      assert_match %r{create_table "legacy_primary_keys", id: :bigint, default: nil}, schema
    end
  end
end
