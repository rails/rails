# frozen_string_literal: true

require "cases/helper"

module SchemaLoadCounter
  extend ActiveSupport::Concern

  module ClassMethods
    attr_accessor :load_schema_calls

    def load_schema!
      self.load_schema_calls ||= 0
      self.load_schema_calls += 1
      super
    end
  end
end

class SchemaLoadingTest < ActiveRecord::TestCase
  def test_basic_model_is_loaded_once
    klass = define_model
    klass.new
    assert_equal 1, klass.load_schema_calls
  end

  def test_model_with_custom_lock_is_loaded_once
    klass = define_model do |c|
      c.table_name = :lock_without_defaults_cust
      c.locking_column = :custom_lock_version
    end
    klass.new
    assert_equal 1, klass.load_schema_calls
  end

  def test_model_with_changed_custom_lock_is_loaded_twice
    klass = define_model do |c|
      c.table_name = :lock_without_defaults_cust
    end
    klass.new
    klass.locking_column = :custom_lock_version
    klass.new
    assert_equal 2, klass.load_schema_calls
  end

  def test_schema_loading_doesnt_query_when_schema_cache_is_loaded
    with_temporary_connection_pool do
      if in_memory_db?
        # Separate connections to an in-memory database create an entirely new database,
        # with an empty schema etc, so we just stub out this schema on the fly.
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.create_table :tasks do |t|
            t.datetime :starting
            t.datetime :ending
          end
        end
      end

      klass = define_model do |c|
        c.table_name = :tasks
      end

      klass.connection_pool.schema_cache.load!
      klass.connection_pool.schema_cache.add("tasks")
      klass.connection_pool.disconnect!
      klass.send(:reload_schema_from_cache)


      assert_no_queries(include_schema: true) do
        klass.load_schema
      end
      assert_equal 1, klass.load_schema_calls
    end
  end

  def test_inheritance_column_change_refreshes_loaded_descendant_content_columns
    klass = define_model { |model| model.table_name = "topics" }
    models = [klass, Class.new(klass)]
    models.each do |model|
      assert_includes model.content_columns.map(&:name), "author_name"
    end

    klass.inheritance_column = "author_name"

    models.each do |model|
      assert_not_includes model.content_columns.map(&:name), "author_name"
    end
  end

  def test_inheritance_column_override_can_read_columns
    klass = define_model do |model|
      model.table_name = "topics"
      def model.inheritance_column = columns_hash.key?("author_name") ? "author_name" : super
    end

    assert_equal "author_name", klass.inheritance_column
    assert_not_includes klass.content_columns.map(&:name), "author_name"
  end

  def test_unloaded_context_retains_its_table_after_model_configuration_changes
    klass = define_model { |model| model.table_name = "topics" }
    context = klass.schema_context
    klass.table_name = "movies"

    assert_includes context.mapped_table.column_names, "title"
    assert_includes klass.column_names, "name"
  end

  def test_failed_schema_load_does_not_publish_the_context
    klass = define_model

    klass.stub(:load_schema!, -> { raise "schema hook failed" }) do
      assert_raises(RuntimeError) { klass.column_names }
    end

    assert_nil klass.current_schema_context
    assert_includes klass.column_names, "id"
  end

  private
    def define_model
      Class.new(ActiveRecord::Base) do
        include SchemaLoadCounter
        self.table_name = :lock_without_defaults
        yield self if block_given?
      end
    end
end

class SchemaLoadingMissingTableTest < ActiveRecord::TestCase
  skip_under_ractor_proxy

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.drop_table(:late_tables, if_exists: true)
  end

  teardown do
    @connection.drop_table(:late_tables, if_exists: true)
  end

  def test_failed_schema_load_is_retried_after_create_table
    model = define_model

    assert_raises(ActiveRecord::StatementInvalid) { model.load_schema }

    create_late_table

    assert_equal ["id", "name"], model.column_names
    record = model.create!(name: "late")
    assert_equal "late", model.find(record.id).name
  end

  def test_schema_loads_from_a_temporary_table
    @connection.create_table(:temporary_schema_tables, temporary: true) { |t| t.string :name }
    model = Class.new(ActiveRecord::Base) { self.table_name = "temporary_schema_tables" }

    model.primary_key
    assert_equal ["id", "name"], model.column_names
    record = model.create!(name: "temporary")
    assert_equal "temporary", model.find_by!(name: record.name).name
  ensure
    @connection.drop_table(:temporary_schema_tables, if_exists: true)
  end

  private
    def define_model
      Class.new(ActiveRecord::Base) do
        def self.name = "LateTable"
        self.table_name = "late_tables"
      end
    end

    def create_late_table(**options)
      @connection.create_table(:late_tables, **options) { |t| t.string :name }
    end
end
