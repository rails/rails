# frozen_string_literal: true

require "cases/helper"

class PostgresqlCollationMigrationTest < ActiveRecord::PostgreSQLTestCase
  class SilentMigration < ActiveRecord::Migration::Current
    def write(*); end
  end

  class CreateCollation < SilentMigration
    def change
      create_collation "case_insensitive",
        provider: "icu",
        locale: "und-u-ks-level2",
        deterministic: false
    end
  end

  class DropCollation < SilentMigration
    def change
      drop_collation "case_insensitive",
        provider: "icu",
        locale: "und-u-ks-level2",
        deterministic: false
    end
  end

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_create_collation_and_drop_collation
    assert_not_includes @connection.collations, "case_insensitive"
    CreateCollation.new.migrate(:up)
    assert_includes @connection.collations, "case_insensitive"
    DropCollation.new.migrate(:up)
    assert_not_includes @connection.collations, "case_insensitive"
  end

  def test_migrate_and_revert_create_collation
    assert_not_includes @connection.collations, "case_insensitive"
    CreateCollation.new.migrate(:up)
    assert_includes @connection.collations, "case_insensitive"
    CreateCollation.new.migrate(:down)
    assert_not_includes @connection.collations, "case_insensitive"
  end

  def test_migrate_and_revert_drop_collation
    @connection.execute <<~SQL
      CREATE COLLATION case_insensitive
        (provider = icu, locale = 'und-u-ks-level2', deterministic = false)
    SQL

    assert_includes @connection.collations, "case_insensitive"
    DropCollation.new.migrate(:up)
    assert_not_includes @connection.collations, "case_insensitive"
    DropCollation.new.migrate(:down)
    assert_includes @connection.collations, "case_insensitive"
  end
end
