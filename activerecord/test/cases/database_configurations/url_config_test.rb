# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class UrlConfigTest < ActiveRecord::TestCase
      def test_schema_dump_parsing
        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?schema_dump=false", {})
        assert_nil config.schema_dump

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?schema_dump=db/foo_schema.rb", {})
        assert_equal "db/foo_schema.rb", config.schema_dump

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo", {})
        assert_equal "schema.rb", config.schema_dump
      end

      def test_query_cache_parsing
        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?query_cache=false", {})
        assert_equal false, config.query_cache

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?query_cache=42", {})
        assert_equal 42, config.query_cache

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?query_cache=forever", {})
        assert_equal "forever", config.query_cache
      end

      def test_replica_parsing
        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo", {})
        assert_nil config.replica?

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?replica=true", {})
        assert_equal true, config.replica?

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?replica=false", {})
        assert_equal false, config.replica?

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?replica=random", {})
        assert_equal true, config.replica?
      end

      def test_database_tasks_parsing
        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo", {})
        assert_equal true, config.database_tasks?

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?database_tasks=random", {})
        assert_equal true, config.database_tasks?

        config = UrlConfig.new("default_env", "primary", "postgres://localhost/foo?database_tasks=false", {})
        assert_equal false, config.database_tasks?
      end
    end
  end
end
