# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlCollationMigrationTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

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

  def test_schema_dump_includes_collations_in_alphabetical_order
    @connection.execute "CREATE COLLATION japanese (provider = libc, locale = 'ja_JP')"
    @connection.execute <<~SQL
      CREATE COLLATION case_insensitive
        (provider = icu, locale = 'und-u-ks-level2', deterministic = false)
    SQL

    output = dump_all_table_schema([])

    assert_includes output, <<-COLL
  # Custom collations defined in this database.
  create_collation "case_insensitive", provider: "icu", lc_collate: "und-u-ks-level2", lc_ctype: "und-u-ks-level2", deterministic: false
  create_collation "german", provider: "libc", lc_collate: "de_DE", lc_ctype: "de_DE", deterministic: true
  create_collation "japanese", provider: "libc", lc_collate: "ja_JP", lc_ctype: "ja_JP", deterministic: true
    COLL
  end

  def test_schema_dump_without_collations_defined
    @connection.execute "DROP COLLATION german"

    output = dump_all_table_schema([])
    assert_not_includes output, "# Custom collations defined in this database."
  end
end
