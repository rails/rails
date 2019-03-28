# frozen_string_literal: true

require "cases/helper"
require "fileutils"

class SchemaCacheSerializerTest < ActiveRecord::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @schema_cache_serializer = ActiveRecord::SchemaCacheSerializer.new(@connection)
    @previous_schema_cache = @connection.schema_cache.dup
  end

  teardown do
    @connection.schema_cache = @previous_schema_cache
  end

  test "#serialize the schema_cache contain all columns" do
    serialized_schema = @schema_cache_serializer.serialize

    assert serialized_schema[:columns]["accounts"]
    assert serialized_schema[:columns]["admin_accounts"]
  end

  test "#serialize the schema_cache contain all indexes" do
    serialized_schema = @schema_cache_serializer.serialize

    assert serialized_schema[:indexes]["accounts"]
    assert serialized_schema[:indexes]["admin_accounts"]
  end

  test "#serialize the schema_cache contain all data_sources" do
    serialized_schema = @schema_cache_serializer.serialize

    assert serialized_schema[:data_sources]["accounts"]
    assert serialized_schema[:data_sources]["admin_accounts"]
  end

  test "#serialize the schema_cache contain all primary_keys" do
    serialized_schema = @schema_cache_serializer.serialize

    assert serialized_schema[:primary_keys]["accounts"]
    assert serialized_schema[:primary_keys]["admin_accounts"]
  end

  test "#serialize does not dump the `tables_to_skip` in the cache" do
    previous_tables_to_skip = @schema_cache_serializer.tables_to_skip.dup
    @schema_cache_serializer.class.tables_to_skip << "accounts"
    @schema_cache_serializer.class.tables_to_skip << "admin_accounts"

    serialized_schema = @schema_cache_serializer.serialize

    assert_not serialized_schema[:primary_keys]["accounts"]
    assert_not serialized_schema[:primary_keys]["admin_accounts"]
  ensure
    @schema_cache_serializer.class.tables_to_skip = previous_tables_to_skip
  end

  test "#deserialize works when using a SchemaCache dumped with Psych" do
    assert_nothing_raised do
      @schema_cache_serializer.deserialize("test/assets/schema_dump_5_1.yml")
    end
  end

  test "#deserialize adds `columns_hash`" do
    filepath = "/tmp/my_schema_cache.yml"
    File.write(filepath, YAML.dump(@schema_cache_serializer.serialize))

    schema_cache = @schema_cache_serializer.deserialize(filepath)

    assert schema_cache[:columns_hash]["accounts"]
    assert schema_cache[:columns_hash]["admin_accounts"]
  ensure
    FileUtils.rm(filepath)
  end

  test "#deserialize returns prematurely when file does not exists" do
    assert_nil @schema_cache_serializer.deserialize("/path/to/unexisting_file.yml")
  end

  test "round trip serialization/deserialization" do
    fill_schema_cache("admin_users")
    column_witness = @connection.schema_cache.columns("admin_users")
    index_witness = @connection.schema_cache.indexes("admin_users").first

    filepath = "/tmp/my_schema_cache.yml"
    File.write(filepath, YAML.dump(@schema_cache_serializer.serialize))

    schema_cache = @schema_cache_serializer.deserialize(filepath)

    assert_equal column_witness, schema_cache[:columns]["admin_users"]
    index = schema_cache[:indexes]["admin_users"].first
    assert_equal index_witness.name, index.name
    assert_equal index_witness.columns, index.columns
    assert_equal index_witness.using, index.using
  ensure
    FileUtils.rm(filepath)
  end

  private
    def fill_schema_cache(*tables)
      tables.each { |table| @previous_schema_cache.add(table) }
    end
end
