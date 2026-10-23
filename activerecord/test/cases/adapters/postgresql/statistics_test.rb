# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlStatisticsTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class SilentMigration < ActiveRecord::Migration::Current
    def write(*); end
  end

  class CreateStatisticsMigration < SilentMigration
    def change
      create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", kinds: [:dependencies]
    end
  end

  class DropStatisticsMigration < SilentMigration
    def change
      drop_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", kinds: [:dependencies], if_exists: true
    end
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :addresses, force: true do |t|
      t.string :city
      t.string :zip_code
      t.string :email
    end
  end

  def teardown
    @connection.drop_table :addresses, if_exists: true
    @connection.drop_schema "test_statistics_schema", if_exists: true
  end

  def test_create_statistics_on_columns
    @connection.create_statistics :addresses, [:zip_code, :city], name: "addresses_city_zip_code_stat", kinds: [:ndistinct, :dependencies]

    statistic = @connection.statistics("addresses").sole
    assert_equal "addresses", statistic.table_name
    assert_equal "addresses_city_zip_code_stat", statistic.name
    assert_equal ["city", "zip_code"], statistic.columns
    assert_equal [:ndistinct, :dependencies], statistic.kinds
  end

  def test_create_statistics_with_all_kinds_by_default
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat"

    assert_equal [:ndistinct, :dependencies, :mcv], @connection.statistics("addresses").sole.kinds
  end

  def test_create_statistics_on_expressions
    skip unless @connection.database_version >= 14_00_00

    @connection.create_statistics :addresses, ["lower(email)"], name: "addresses_lower_email_stat"
    @connection.create_statistics :addresses, [:city, "lower(email)"], name: "addresses_city_lower_email_stat", kinds: [:mcv]

    single, multiple = @connection.statistics("addresses").sort_by { |statistic| statistic.columns.size }
    assert_equal ["lower((email)::text)"], single.columns
    assert_equal [], single.kinds
    assert_equal ["city", "lower((email)::text)"], multiple.columns
    assert_equal [:mcv], multiple.kinds
  end

  def test_create_statistics_without_name
    @connection.create_statistics :addresses, [:city, :zip_code]

    assert_match(/\Astat_rails_[0-9a-f]{10}\z/, @connection.statistics("addresses").sole.name)

    @connection.drop_statistics :addresses, [:city, :zip_code]
    assert_empty @connection.statistics("addresses")
  end

  def test_create_statistics_if_not_exists
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat"
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", if_not_exists: true

    assert_equal 1, @connection.statistics("addresses").size
  end

  def test_drop_statistics
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat"
    @connection.drop_statistics :addresses, name: "addresses_city_zip_code_stat"
    assert_empty @connection.statistics("addresses")

    @connection.drop_statistics :addresses, name: "addresses_city_zip_code_stat", if_exists: true
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.transaction(requires_new: true) do
        @connection.drop_statistics :addresses, name: "addresses_city_zip_code_stat"
      end
    end
  end

  def test_statistics_on_a_schema_qualified_table
    @connection.create_schema "test_statistics_schema"
    @connection.create_table "test_statistics_schema.addresses" do |t|
      t.string :city
      t.string :zip_code
    end
    @connection.create_statistics "test_statistics_schema.addresses", [:city, :zip_code], name: "addresses_city_zip_code_stat"

    assert_empty @connection.statistics("addresses")
    statistic = @connection.statistics("test_statistics_schema.addresses").sole
    assert_equal "addresses_city_zip_code_stat", statistic.name
    assert_equal "test_statistics_schema", @connection.select_value(<<~SQL)
      SELECT n.nspname FROM pg_statistic_ext s JOIN pg_namespace n ON n.oid = s.stxnamespace
      WHERE s.stxname = 'addresses_city_zip_code_stat'
    SQL

    @connection.drop_statistics "test_statistics_schema.addresses", name: "addresses_city_zip_code_stat"
    assert_empty @connection.statistics("test_statistics_schema.addresses")
  ensure
    @connection.drop_schema "test_statistics_schema", if_exists: true
  end

  def test_schema_dump_includes_statistics_after_the_table
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", kinds: [:dependencies]
    @connection.create_statistics :addresses, [:city, :email], name: "addresses_city_email_stat"

    output = dump_table_schema("addresses")
    assert_match %r{create_table "addresses".*?^  end\n\n  create_statistics "addresses", \["city", "email"\], name: "addresses_city_email_stat"\n  create_statistics "addresses", \["city", "zip_code"\], name: "addresses_city_zip_code_stat", kinds: \[:dependencies\]\n}m, output
  end

  def test_schema_dump_round_trips_statistics
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", kinds: [:dependencies, :mcv]
    if @connection.database_version >= 14_00_00
      @connection.create_statistics :addresses, ["lower(email)"], name: "addresses_lower_email_stat"
    end

    before = @connection.statistics("addresses")
    statements = dump_table_schema("addresses").lines.grep(/create_statistics/)
    assert_equal before.size, statements.size

    before.each { |statistic| @connection.drop_statistics :addresses, name: statistic.name }
    assert_empty @connection.statistics("addresses")

    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define { statements.each { |statement| eval(statement) } }
    end

    assert_equal before, @connection.statistics("addresses")
  end

  def test_create_statistics_is_reversible
    migration = CreateStatisticsMigration.new
    migration.migrate(:up)
    assert_equal ["addresses_city_zip_code_stat"], @connection.statistics("addresses").map(&:name)

    migration.migrate(:down)
    assert_empty @connection.statistics("addresses")
  end

  def test_drop_statistics_is_reversible
    @connection.create_statistics :addresses, [:city, :zip_code], name: "addresses_city_zip_code_stat", kinds: [:dependencies]

    migration = DropStatisticsMigration.new
    migration.migrate(:up)
    assert_empty @connection.statistics("addresses")

    migration.migrate(:down)
    assert_equal [:dependencies], @connection.statistics("addresses").sole.kinds
  end
end
