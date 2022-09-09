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

  class DropEnumMigration < SilentMigration
    def change
      drop_enum :color, ["blue", "green"], if_exists: true
    end
  end

  class AddAndValidateCheckConstraint < SilentMigration
    def change
      add_check_constraint :settings, "value >= 0", name: "positive_value", validate: false
      validate_check_constraint :settings, name: "positive_value"
    end
  end

  class AddAndValidateForeignKey < SilentMigration
    def change
      add_foreign_key :bars, :foos, validate: false
      validate_foreign_key :bars, :foos
    end
  end

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
  end

  teardown do
    @connection.drop_table "settings", if_exists: true
    @connection.drop_table "enums", if_exists: true
    @connection.drop_table "bars", if_exists: true
    @connection.drop_table "foos", if_exists: true
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

  def test_migrate_revert_create_enum
    CreateEnumMigration.new.migrate(:up)

    assert @connection.column_exists?(:enums, :best_color, sql_type: "color", default: "blue", null: false)
    assert_equal [["color", "blue,green"]], @connection.enum_types

    CreateEnumMigration.new.migrate(:down)

    assert_not @connection.table_exists?(:enums)
    assert_equal [], @connection.enum_types
  end

  def test_migrate_revert_drop_enum
    assert_equal [], @connection.enum_types

    assert_nothing_raised { DropEnumMigration.new.migrate(:up) }
    assert_equal [], @connection.enum_types

    DropEnumMigration.new.migrate(:down)
    assert_equal [["color", "blue,green"]], @connection.enum_types
  end

  def test_migrate_revert_add_and_validate_check_constraint
    @connection.create_table(:settings) do |t|
      t.integer :value
    end

    AddAndValidateCheckConstraint.new.migrate(:up)
    assert @connection.check_constraint_exists?(:settings, name: "positive_value")
    AddAndValidateCheckConstraint.new.migrate(:down)
    assert_not @connection.check_constraint_exists?(:settings, name: "positive_value")
  end

  def test_migrate_revert_add_and_validate_foreign_key
    @connection.create_table(:foos)
    @connection.create_table(:bars) do |t|
      t.integer :foo_id
    end

    AddAndValidateForeignKey.new.migrate(:up)
    assert @connection.foreign_key_exists?(:bars, :foos)
    AddAndValidateForeignKey.new.migrate(:down)
    assert_not @connection.foreign_key_exists?(:bars, :foos)
  end
end
