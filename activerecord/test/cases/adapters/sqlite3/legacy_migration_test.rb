require "cases/helper"

class SqliteLegacyMigrationTest < ActiveRecord::SQLite3TestCase
  self.use_transactional_tests = false

  class GenerateTableWithoutBigint < ActiveRecord::Migration[5.0]
    def change
      create_table :legacy_integer_pk do |table|
        table.string :foo
      end

      create_table :override_pk, id: :bigint do |table|
        table.string :bar
      end
    end
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection

    @migration_verbose_old = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    migrations = [GenerateTableWithoutBigint.new(nil, 1)]

    ActiveRecord::Migrator.new(:up, migrations).migrate
  end

  def teardown
    ActiveRecord::Migration.verbose = @migration_verbose_old
    @connection.drop_table("legacy_integer_pk")
    @connection.drop_table("override_pk")
    ActiveRecord::SchemaMigration.delete_all rescue nil
    super
  end

  def test_create_table_uses_integer_as_pkey_by_default
    col = column(:legacy_integer_pk, :id)
    assert_equal "INTEGER", sql_type_for(col)
    assert primary_key?(:legacy_integer_pk, "id"), "id is not primary key"
  end

  private

    def column(table_name, column_name)
      ActiveRecord::Base.connection
        .columns(table_name.to_s)
        .detect { |c| c.name == column_name.to_s }
    end

    def sql_type_for(col)
      col && col.sql_type
    end

    def primary_key?(table_name, column)
      ActiveRecord::Base.connection.execute("PRAGMA table_info(#{table_name})").find { |col| col["name"] == column }["pk"] == 1
    end
end
