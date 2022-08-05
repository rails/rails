# frozen_string_literal: true

require "cases/helper"

class PostgresqlInvertibleMigrationTest < ActiveRecord::PostgreSQLTestCase
  class SilentMigration < ActiveRecord::Migration::Current
    def write(*); end
  end

  class ExpressionIndexMigration < SilentMigration
    def change
      create_table("settings") do |t|
        t.column :data, :jsonb
      end

      add_index :settings,
                "(data->'foo')",
                using: :gin,
                name: "index_settings_data_foo"
    end
  end

  class CreateEnumMigration < SilentMigration
    def change
      create_enum :color, ["blue", "green"]
      create_table :enums do |t|
        t.enum :best_color, enum_type: "color", default: "blue", null: false
      end
    end
  end

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
  end

  teardown do
    @connection.drop_table "settings", if_exists: true
    @connection.drop_table "enums", if_exists: true
  end

  def test_migrate_revert_add_index_with_expression
    ExpressionIndexMigration.new.migrate(:up)

    assert @connection.table_exists?(:settings)
    assert @connection.index_exists?(:settings, nil, name: "index_settings_data_foo"),
           "index on index_settings_data_foo should exist"

    ExpressionIndexMigration.new.migrate(:down)

    assert_not @connection.table_exists?(:settings)
    assert_not @connection.index_exists?(:settings, nil, name: "index_settings_data_foo"),
               "index index_settings_data_foo should not exist"
  end

  def test_revert_create_enum
    CreateEnumMigration.new.migrate(:up)

    assert @connection.column_exists?(:enums, :best_color, sql_type: "color", default: "blue", null: false)
    assert_equal [["color", "blue,green"]], @connection.enum_types

    CreateEnumMigration.new.migrate(:down)

    assert_not @connection.table_exists?(:enums)
    assert_equal [], @connection.enum_types
  end
end
