# frozen_string_literal: true

require "cases/helper"

class SchemaContextTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def teardown
    # Clean up the connection handler to remove shards
    clean_up_connection_handler

    # Ensure we're back on the default connection
    ActiveRecord::Base.establish_connection(:arunit)

    # Drop our test table
    ActiveRecord::Base.lease_connection.drop_table :schema_test_items, if_exists: true
  end

  def test_serialize_works_independently_per_schema_context
    # Create an abstract model class for multi-shard configuration
    # This isolates our test from ActiveRecord::Base
    abstract_model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      def self.name
        "SchemaContextTestBase"
      end
    end

    # Configure the abstract model with multiple shards, each with different schema contexts
    # Force both adapters to use prepared_statements: false so they share the same cache bucket
    arunit_config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(
      schema_context: "context_a",
      prepared_statements: false
    )

    abstract_model.connects_to shards: {
      default: { writing: arunit_config },
      shard_b: { writing: { adapter: "sqlite3", database: ":memory:", schema_context: "context_b", prepared_statements: false } }
    }

    # Create schema_test_items table in default shard
    abstract_model.connected_to(shard: :default) do
      abstract_model.lease_connection.create_table :schema_test_items, force: true do |t|
        t.string :name
        t.text :metadata
        t.timestamps
      end
    end

    # Create schema_test_items table in shard_b
    abstract_model.connected_to(shard: :shard_b) do
      abstract_model.lease_connection.create_table :schema_test_items, force: true do |t|
        t.string :name
        t.text :metadata
        t.timestamps
      end
    end

    # Create a model class that inherits from the abstract model
    test_model = Class.new(abstract_model) do
      self.table_name = "schema_test_items"

      serialize :metadata, coder: JSON

      def self.name
        "SchemaTestItem"
      end
    end

    abstract_model.connected_to(shard: :default) do
      record_a = test_model.create!(name: "Item A", metadata: { foo: "bar" })
      assert_equal({ "foo" => "bar" }, record_a.reload.metadata)
    end

    abstract_model.connected_to(shard: :shard_b) do
      record_b = test_model.create!(name: "Item B", metadata: { foo: "baz" })
      assert_equal({ "foo" => "baz" }, record_b.reload.metadata)
    end

    # Do the SQLite find_by FIRST to cache its double-quoted SQL
    abstract_model.connected_to(shard: :shard_b) do
      record_b = test_model.find_by(name: "Item B")
      record_b.metadata = { new: "data" }
      record_b.save!
      assert_equal({ "new" => "data" }, record_b.reload.metadata)
    end

    # Now try MySQL which will reuse the SQLite-quoted statement and fail
    # because MySQL doesn't accept double-quoted identifiers
    abstract_model.connected_to(shard: :default) do
      record_a = test_model.find_by(name: "Item A")
      record_a.metadata = { new: "data" }
      record_a.save!
      assert_equal({ "new" => "data" }, record_a.reload.metadata)
    end
  ensure
    # Remove the connection handler for our abstract model
    ActiveRecord::Base.connection_handler.instance_variable_get(:@connection_name_to_pool_manager).delete("SchemaContextTestBase")
  end
end
