# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "support/schema_dumping_helper"

module SharedEnumTestCases
  include ConnectionHelper
  include SchemaDumpingHelper

  class EnumTest < ActiveRecord::Base
    self.table_name = "enum_tests"

    enum :current_mood, {
      sad: "sad",
      okay: "ok", # different spelling
      happy: "happy",
      aliased_field: "happy"
    }, prefix: true
  end

  def setup
    super
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table("enum_tests") do |t|
      t.enum :current_mood, enum_type: "mood", values: ["sad", "ok", "happy"], default: "sad"
    end
  end

  def teardown
    @connection.drop_table "enum_tests", if_exists: true
    if current_adapter?(:PostgreSQLAdapter)
      @connection.enum_types.each do |enum_type, values|
        @connection.drop_enum enum_type
      end
    end

    super
  end

  def test_enum_defaults
    assert_equal "sad", EnumTest.column_defaults["current_mood"]
    assert_equal "sad", EnumTest.new.current_mood
  end

  def test_enum_mapping
    @connection.execute "INSERT INTO enum_tests VALUES (1, 'sad');"
    enum = EnumTest.first
    assert_equal "sad", enum.current_mood

    enum.current_mood = "happy"
    enum.save!

    assert_equal "happy", enum.reload.current_mood
  end

  def test_invalid_enum_update
    @connection.execute "INSERT INTO enum_tests VALUES (1, 'sad');"
    enum = EnumTest.first

    assert_raise ArgumentError do
      enum.current_mood = "angry"
    end
  end

  def test_enum_type_cast
    enum = EnumTest.new
    enum.current_mood = :happy

    assert_equal "happy", enum.current_mood
  end

  def test_assigning_enum_to_nil
    model = EnumTest.new(current_mood: nil)

    assert_nil model.current_mood
    assert model.save
    assert_nil model.reload.current_mood
  end
end
