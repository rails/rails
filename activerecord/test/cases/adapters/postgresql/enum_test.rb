# frozen_string_literal: true

require "cases/helper"
require "cases/enum_shared_test_cases"

module PostgresqlEnumSharedTestCases
  include SharedEnumTestCases

  def test_column
    EnumTest.reset_column_information
    column = EnumTest.columns_hash["current_mood"]
    assert_equal :enum, column.type
    assert_equal enum_type, column.sql_type
    assert_not_predicate column, :array?

    type = EnumTest.type_for_attribute("current_mood")
    assert_not_predicate type, :binary?
  end

  def test_no_oid_warning
    @connection.execute "INSERT INTO enum_tests VALUES (1, 'sad');"
    stderr_output = capture(:stderr) { EnumTest.first }

    assert_predicate stderr_output, :blank?
  end

  def test_schema_dump_renamed_enum
    @connection.rename_enum enum_type, :feeling

    output = dump_table_schema("enum_tests")

    assert_includes output, 'create_enum "feeling", ["sad", "ok", "happy"]'
    assert_includes output, 't.enum "current_mood", default: "sad", enum_type: "feeling", values: ["sad", "ok", "happy"]'
  end

  def test_schema_dump_renamed_enum_with_to_option
    @connection.rename_enum enum_type, to: :feeling

    output = dump_table_schema("enum_tests")

    assert_includes output, 'create_enum "feeling", ["sad", "ok", "happy"]'
    assert_includes output, 't.enum "current_mood", default: "sad", enum_type: "feeling", values: ["sad", "ok", "happy"]'
  end

  def test_schema_dump_added_enum_value
    skip("Adding enum values can not be run in a transaction") if @connection.database_version < 10_00_00

    @connection.add_enum_value enum_type, :angry, before: :ok
    @connection.add_enum_value enum_type, :nervous, after: :ok
    @connection.add_enum_value enum_type, :glad

    assert_nothing_raised do
      @connection.add_enum_value enum_type, :glad, if_not_exists: true
      @connection.add_enum_value enum_type, :curious, if_not_exists: true
    end

    output = dump_table_schema("enum_tests")

    assert_includes output, "create_enum \"#{enum_type}\", [\"sad\", \"angry\", \"ok\", \"nervous\", \"happy\", \"glad\", \"curious\"]"
  end

  def test_schema_dump_renamed_enum_value
    skip("Renaming enum values is only supported in PostgreSQL 10 or later") if @connection.database_version < 10_00_00

    @connection.rename_enum_value enum_type, from: :ok, to: :okay

    output = dump_table_schema("enum_tests")

    assert_includes output, "create_enum \"#{enum_type}\", [\"sad\", \"okay\", \"happy\"]"
  end

  def test_create_enum_type_with_different_values
    assert_raises ActiveRecord::StatementInvalid do
      @connection.create_enum enum_type, ["mad", "glad"]
    end
  end

  def test_works_with_activerecord_enum
    model = EnumTest.create!
    model.current_mood_okay!

    model = EnumTest.find(model.id)
    assert_equal "okay", model.current_mood

    model.current_mood = "happy"
    model.save!

    model = EnumTest.find(model.id)
    assert_predicate model, :current_mood_happy?
  end
end

class PostgresqlEnumTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlEnumSharedTestCases

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.transaction do
      @connection.create_enum("mood", ["sad", "ok", "happy"])
      @connection.create_table("enum_tests") do |t|
        t.column :current_mood, :mood, default: "sad"
      end
    end
  end

  def test_schema_dump
    @connection.add_column "enum_tests", "good_mood", enum_type, default: "happy", null: false
    @connection.add_column "enum_tests", "bad_mood", :enum, values: ["angry", "mad", "sad"], default: "sad", null: false
    @connection.add_column "enum_tests", "party_mood", :enum, values: ["excited", "happy"], default: "happy", enum_type: "fun_mood", null: false

    output = dump_table_schema("enum_tests")

    assert_includes output, "# Note that some types may not work with other database engines. Be careful if changing database."

    assert_includes output, "create_enum \"#{enum_type}\", [\"sad\", \"ok\", \"happy\"]"
    assert_includes output, 'create_enum "bad_mood", ["angry", "mad", "sad"]'
    assert_includes output, 'create_enum "fun_mood", ["excited", "happy"]'

    assert_includes output, "t.enum \"good_mood\", default: \"happy\", null: false, enum_type: \"#{enum_type}\", values: [\"sad\", \"ok\", \"happy\"]"
    assert_includes output, 't.enum "bad_mood", default: "sad", null: false, values: ["angry", "mad", "sad"]'
    assert_includes output, 't.enum "party_mood", default: "happy", null: false, enum_type: "fun_mood", values: ["excited", "happy"]'
  end

  def test_schema_load
    original, $stdout = $stdout, StringIO.new

    ActiveRecord::Schema.define do
      create_enum :color, ["blue", "green"]

      change_table :enum_tests do |t|
        t.enum :best_color, enum_type: "color", values: ["blue", "green"], default: "blue", null: false
      end
    end

    assert @connection.column_exists?(:enum_tests, :best_color, "enum", values: ["blue", "green"], default: "blue", null: false)
  ensure
    $stdout = original
  end

  def test_enum_column_without_values_or_enum_type_raises_error
    error = assert_raises(ArgumentError) do
      @connection.add_column :enum_tests, :best_color, :enum, null: false
    end

    assert_equal "enum_type or values is required for enums", error.message
  end

  def test_drop_enum
    @connection.create_enum :unused, []

    assert_nothing_raised do
      @connection.drop_enum "unused"
    end

    assert_nothing_raised do
      @connection.drop_enum "unused", if_exists: true
    end

    assert_raises ActiveRecord::StatementInvalid do
      @connection.drop_enum "unused"
    end
  end

  def test_enum_type_scoped_to_schemas
    with_test_schema("test_schema") do
      @connection.create_enum("mood_in_other_schema", ["sad", "ok", "happy"])

      assert_nothing_raised do
        @connection.create_table("enum_tests_in_other_schema") do |t|
          t.column :current_mood, :mood_in_other_schema, default: "happy", null: false
        end
      end

      assert @connection.table_exists?("enum_tests_in_other_schema")
    end
  end

  def test_enum_type_explicit_schema
    @connection.create_schema("test_schema")
    @connection.create_enum("test_schema.mood_in_other_schema", ["sad", "ok", "happy"])

    @connection.create_table("test_schema.enum_tests_in_other_schema") do |t|
      t.column :current_mood, "test_schema.mood_in_other_schema"
    end

    assert @connection.table_exists?("test_schema.enum_tests_in_other_schema")

    assert_nothing_raised do
      @connection.drop_table("test_schema.enum_tests_in_other_schema")
      @connection.drop_enum("test_schema.mood_in_other_schema")
    end
  ensure
    @connection.drop_schema("test_schema", if_exists: true)
  end

  def test_schema_dump_scoped_to_schemas
    @connection.create_schema("other_schema")
    @connection.create_enum("other_schema.mood_in_other_schema", ["sad", "ok", "happy"])

    with_test_schema("test_schema") do
      @connection.create_enum("mood_in_test_schema", ["sad", "ok", "happy"])
      @connection.create_table("enum_tests_in_test_schema") do |t|
        t.column :current_mood, :mood_in_test_schema
      end

      output = dump_table_schema("enum_tests_in_test_schema")

      assert_includes output, "create_enum \"public.#{enum_type}\", [\"sad\", \"ok\", \"happy\"]"
      assert_includes output, 'create_enum "mood_in_test_schema", ["sad", "ok", "happy"]'
      assert_includes output, 't.enum "current_mood", enum_type: "mood_in_test_schema"'
      assert_not_includes output, 'create_enum "other_schema.mood_in_other_schema"'
    end
  ensure
    @connection.drop_schema("other_schema")
  end

  def test_schema_load_scoped_to_schemas
    silence_stream($stdout) do
      with_test_schema("test_schema", drop: false) do
        ActiveRecord::Schema.define do
          create_enum "mood_in_test_schema", ["sad", "ok", "happy"]
          create_enum "public.mood", ["sad", "ok", "happy"]

          create_table "enum_tests_in_test_schema", force: :cascade do |t|
            t.enum "current_mood", enum_type: "mood_in_test_schema"
          end
        end

        assert @connection.column_exists?(:enum_tests_in_test_schema, :current_mood, sql_type: "mood_in_test_schema")
      end

      # This is outside `with_test_schema`, so we need to explicitly specify which schema we query
      assert @connection.column_exists?("test_schema.enum_tests_in_test_schema", :current_mood, sql_type: "test_schema.mood_in_test_schema")
    end
  ensure
    @connection.drop_schema("test_schema")
  end

  private
    def enum_type
      "mood"
    end

    def with_test_schema(name, drop: true)
      old_search_path = @connection.schema_search_path
      @connection.create_schema(name)
      @connection.schema_search_path = "#{name}, public"
      yield
    ensure
      @connection.drop_schema(name) if drop
      @connection.schema_search_path = old_search_path
      @connection.schema_cache.clear!
    end
end

class PostgresqlEnumWithValuesAndEnumTypeTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlEnumSharedTestCases

  private
    def enum_type
      "mood"
    end
end

class PostgresqlEnumWithValuesTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlEnumSharedTestCases

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.transaction do
      @connection.create_table("enum_tests") do |t|
        t.enum :current_mood, values: ["sad", "ok", "happy"], default: "sad"
      end
    end
  end

  private
    def enum_type
      "current_mood"
    end
end
