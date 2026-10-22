# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlIdentityTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class IdentityItem < ActiveRecord::Base
    self.table_name = "postgresql_identity_items"
  end

  setup do
    @connection = ActiveRecord::Base.lease_connection
  end

  teardown do
    @connection.drop_table "postgresql_identity_items", if_exists: true
    IdentityItem.reset_column_information
  end

  def test_identity_primary_key
    @connection.create_table "postgresql_identity_items", id: :bigint, identity: true

    column = IdentityItem.columns_hash["id"]
    assert_equal "bigint", column.sql_type
    assert_equal "d", column.identity?
    assert_not_predicate column, :serial?
    assert_nil column.default_function

    assert_equal [1, 2], 2.times.map { IdentityItem.create!.id }
  end

  def test_identity_false_primary_key
    @connection.create_table "postgresql_identity_items", id: :bigint, identity: false

    column = IdentityItem.columns_hash["id"]
    assert_not_predicate column, :identity?
    assert_predicate column, :serial?
  end

  def test_identity_rejects_values_other_than_true_or_false
    error = assert_raises(ArgumentError) do
      @connection.create_table "postgresql_identity_items", id: :bigint, identity: :always
    end
    assert_equal "The :identity option must be true or false, got :always", error.message

    @connection.create_table "postgresql_identity_items"
    assert_raises(ArgumentError) do
      @connection.add_column "postgresql_identity_items", :number, :bigint, identity: "true"
    end
  end

  def test_identity_requires_explicit_integer_type_for_primary_key
    error = assert_raises(ArgumentError) do
      @connection.create_table "postgresql_identity_items", identity: true
    end
    assert_equal "The :identity option requires an explicit integer type such as :bigint", error.message

    assert_raises(ArgumentError) do
      @connection.create_table "postgresql_identity_items", id: false do |t|
        t.primary_key :id, identity: true
      end
    end

    @connection.create_table "postgresql_identity_items", id: false do |t|
      t.string :name
    end
    assert_raises(ArgumentError) do
      @connection.add_column "postgresql_identity_items", :id, :primary_key, identity: true
    end
  end

  def test_identity_column
    @connection.create_table "postgresql_identity_items" do |t|
      t.bigint :number, identity: true
    end

    column = IdentityItem.columns_hash["number"]
    assert_equal "d", column.identity?
    assert_not column.null

    assert_equal [1, 2], 2.times.map { IdentityItem.create!.reload.number }
  end

  def test_add_identity_column
    @connection.create_table "postgresql_identity_items"
    @connection.add_column "postgresql_identity_items", :number, :bigint, identity: true

    assert_equal "d", IdentityItem.columns_hash["number"].identity?
  end

  def test_change_column_rejects_identity
    @connection.create_table "postgresql_identity_items", id: :serial

    error = assert_raises(ArgumentError) do
      @connection.change_column "postgresql_identity_items", :id, :bigint, identity: true
    end
    assert_equal "change_column does not support the :identity option", error.message

    assert_raises(ArgumentError) do
      @connection.change_table "postgresql_identity_items", bulk: true do |t|
        t.change :id, :bigint, identity: false
      end
    end

    column = IdentityItem.columns_hash["id"]
    assert_equal "integer", column.sql_type
    assert_predicate column, :serial?
  end

  def test_schema_dump_identity_primary_key
    @connection.create_table "postgresql_identity_items", id: :bigint, identity: true

    assert_round_trip %r{create_table "postgresql_identity_items", id: \{ type: :bigint, identity: true \}, force: :cascade do \|t\|$}
  end

  def test_schema_dump_integer_identity_primary_key
    @connection.create_table "postgresql_identity_items", id: :integer, identity: true

    assert_round_trip %r{create_table "postgresql_identity_items", id: \{ type: :integer, identity: true \}, force: :cascade do \|t\|$}
  end

  def test_schema_dump_generated_always_identity_column
    @connection.create_table "postgresql_identity_items"
    @connection.execute "ALTER TABLE postgresql_identity_items ADD COLUMN number bigint GENERATED ALWAYS AS IDENTITY"

    output = dump_table_schema "postgresql_identity_items"
    assert_match %r{t\.bigint "number", null: false, identity: true$}, output
  end

  def test_schema_dump_identity_column
    @connection.create_table "postgresql_identity_items" do |t|
      t.bigint :number, identity: true
    end

    assert_round_trip %r{t\.bigint "number", null: false, identity: true$}
  end

  def test_schema_dump_identity_column_in_composite_primary_key
    @connection.create_table "postgresql_identity_items", primary_key: [:another_id, :id] do |t|
      t.integer :another_id, null: false
      t.integer :id, null: false, identity: true
    end

    output = assert_round_trip %r{create_table "postgresql_identity_items", primary_key: \["another_id", "id"\], force: :cascade do \|t\|$}
    assert_match %r{t\.integer "id", null: false, identity: true$}, output
  end

  def test_schema_dump_test_schema_identity_tables
    output = dump_table_schema "postgresql_identity_table", "cpk_postgresql_identity_table"

    assert_match %r{create_table "postgresql_identity_table", id: \{ type: :integer, identity: true \}, force: :cascade do \|t\|$}, output
    assert_match %r{create_table "cpk_postgresql_identity_table", primary_key: \["another_id", "id"\], force: :cascade do \|t\|$}, output
    assert_match %r{t\.integer "id", null: false, identity: true$}, output
  end

  private
    def assert_round_trip(pattern)
      output = dump_table_schema "postgresql_identity_items"
      assert_match pattern, output
      assert_no_match %r{default: nil}, output

      @connection.drop_table "postgresql_identity_items"
      @connection.instance_eval(output[/^  create_table .*?^  end$/m])
      IdentityItem.reset_column_information

      assert_equal output, dump_table_schema("postgresql_identity_items")
      output
    end
end
