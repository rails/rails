# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class UrlConfigTest < ActiveRecord::TestCase
      def test_schema_dump_set_to_false
        config = UrlConfig.new("default_env", "primary", "postges://localhost/foo?schema_dump=false", {})
        assert_nil config.schema_dump
      end

      def test_schema_dump_set_to_path
        config = UrlConfig.new("default_env", "primary", "postges://localhost/foo?schema_dump=db/foo_schema.rb", {})
        assert_equal "db/foo_schema.rb", config.schema_dump
      end

      def test_schema_dump_unset
        config = UrlConfig.new("default_env", "primary", "postges://localhost/foo", {})
        assert_equal "schema.rb", config.schema_dump
      end
    end
  end
end
