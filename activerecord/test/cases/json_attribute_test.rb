# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

class JsonAttributeTest < ActiveRecord::TestCase
  include JSONSharedTestCases
  self.use_transactional_tests = false

  class JsonDataTypeOnText < ActiveRecord::Base
    self.table_name = "json_data_type"

    attribute :payload,  :json
    attribute :settings, :json

    store_accessor :settings, :resolution
  end

  class JsonDataTypeWithSchema < ActiveRecord::Base
    self.table_name = "json_data_type"

    attribute :settings, :json

    has_json :settings, max_invites: 10, beta: :boolean
  end

  def setup
    super
    @connection.drop_table("json_data_type", if_exists: true)
    main_ractor_connection(@connection).create_table("json_data_type") do |t|
      t.string "payload"
      t.string "settings"
    end
  end

  def test_invalid_json_can_be_updated
    model = klass.create!
    @connection.execute("UPDATE #{klass.table_name} SET payload = '---'")

    model.reload
    assert_equal "---", model.payload_before_type_cast
    assert_error_reported(JSON::ParserError) do
      assert_nil model.payload
    end

    model.update(payload: "no longer invalid")
    assert_equal("no longer invalid", model.payload)
  end

  def test_has_json_read_of_null_column_is_not_a_change
    model = JsonDataTypeWithSchema.create!
    @connection.execute("UPDATE #{JsonDataTypeWithSchema.table_name} SET settings = NULL WHERE id = #{model.id}")
    model.reload

    assert_equal 10, model.settings.max_invites
    assert_not model.settings.beta?
    assert_not_predicate model, :changed?
  end

  def test_has_json_read_of_empty_object_is_not_a_change
    model = JsonDataTypeWithSchema.create!
    @connection.execute("UPDATE #{JsonDataTypeWithSchema.table_name} SET settings = '{}' WHERE id = #{model.id}")
    model.reload

    assert_equal 10, model.settings.max_invites
    assert_not_predicate model, :changed?
  end

  def test_has_json_read_on_new_record_is_not_a_change
    model = JsonDataTypeWithSchema.new
    model.settings.max_invites

    assert_not_predicate model, :changed?
  end

  def test_has_json_writes_mark_record_as_changed
    model = JsonDataTypeWithSchema.create!
    model.settings.beta = "1"

    assert_predicate model, :settings_changed?
    assert_equal true, model.settings.beta
  end

  def test_has_json_persists_defaults_on_save
    model = JsonDataTypeWithSchema.create!

    assert_equal({ "max_invites" => 10, "beta" => nil }, model.reload[:settings])
  end

  def test_has_json_leaves_non_object_json_alone
    model = JsonDataTypeWithSchema.create!
    @connection.execute("UPDATE #{JsonDataTypeWithSchema.table_name} SET settings = '[1, 2]' WHERE id = #{model.id}")
    model.reload

    assert_equal [1, 2], model[:settings]
    assert_not_predicate model, :changed?
  end

  private
    def column_type
      :string
    end

    def klass
      JsonDataTypeOnText
    end
end
