# frozen_string_literal: true

require "active_support/core_ext/object/with"

module PGSchemaHelper
  def with_schema_search_path(schema_search_path)
    @connection.schema_search_path = schema_search_path
    @connection.schema_cache.clear!
    yield if block_given?
  ensure
    @connection.schema_search_path = "'$user', public"
    @connection.schema_cache.clear!
  end

  def with_dump_schemas(value, &block)
    ActiveRecord.with(dump_schemas: value, &block)
  end
end
