# frozen_string_literal: true

require "cases/helper"

class PersistenceWithoutPkTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  teardown do
    with_lease_connection do |connection|
      connection.drop_table(:destroy_without_primary_keys, if_exists: true)
      connection.drop_table(:update_without_primary_keys, if_exists: true)
    end
  end

  def test_destroy_raises_unknown_primary_key_for_models_without_primary_key
    model_class = build_model_without_primary_key(:destroy_without_primary_keys)
    record = model_class.create!(name: "example")

    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { record.destroy }
    assert_includes error.message, "ActiveRecord cannot destroy records without a primary key"
    assert_includes error.message, "Add a primary key or use dependent: :delete_all"
  end

  def test_update_raises_unknown_primary_key_for_models_without_primary_key
    model_class = build_model_without_primary_key(:update_without_primary_keys)
    record = model_class.create!(name: "example")

    record.name = "changed"
    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { record.save }
    assert_includes error.message, "ActiveRecord cannot update records without a primary key"
    assert_includes error.message, "Add a primary key or use update_all"

    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { record.update(name: "changed again") }
    assert_includes error.message, "ActiveRecord cannot update records without a primary key"
    assert_includes error.message, "Add a primary key or use update_all"
  end

  private
    def build_model_without_primary_key(table_name)
      with_lease_connection do |connection|
        connection.create_table(table_name, id: false, force: true) do |t|
          t.string :name
        end
      end

      Class.new(ActiveRecord::Base) do
        self.table_name = table_name
        self.primary_key = nil

        def self.name
          "PersistenceWithoutPk#{object_id}"
        end
      end
    end

    def with_lease_connection
      connection = ActiveRecord::Base.lease_connection
      yield connection
    ensure
      ActiveRecord::Base.connection_pool.release_connection(connection) if connection
    end
end
