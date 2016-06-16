require "cases/helper"

class PostgreslqLegacyMigrationTest < ActiveRecord::PostgreSQLTestCase
  class GenerateTableWithoutBigserial < ActiveRecord::Migration::Compatibility::V5_0
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

    @migration_verbose_old = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    migrations = [GenerateTableWithoutBigserial.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations).migrate
  end

  def teardown
    ActiveRecord::Migration.verbose = @migration_verbose_old

    super
  end

  def test_create_table_uses_serial_as_pkey_by_default
    assert_equal "integer", sql_type_for(:legacy_integer_pk, :id)
  end

  def test_create_tables_respects_pk_column_type_override
    assert_equal "bigint", sql_type_for(:override_pk, :id)
  end

  private

  def sql_type_for(table_name, column_name)
    column = ActiveRecord::Base.connection
      .columns(table_name.to_s)
      .detect { |c| c.name == column_name.to_s }

    column && column.sql_type
  end
end
