# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class TypeMapCacheTest < ActiveRecord::TestCase
        if current_adapter?(:PostgreSQLAdapter)
          def setup
            @connection = ActiveRecord::Base.connection
            @type_map_cache = TypeMapCache.instance
          end

          def test_type_map_cache_init_with_schema_cache
            assert(@type_map_cache.additional_type_records.empty?)
            assert(@type_map_cache.known_coder_type_records.empty?)

            TypeMapCache.init(@connection.schema_cache)

            assert_not(@type_map_cache.additional_type_records.empty?)
            assert_not(@type_map_cache.known_coder_type_records.empty?)
          end

          def test_type_map_cache_clear
            TypeMapCache.init(@connection.schema_cache)

            assert_not(@type_map_cache.additional_type_records.empty?)
            assert_not(@type_map_cache.known_coder_type_records.empty?)

            TypeMapCache.clear

            assert(@type_map_cache.additional_type_records.empty?)
            assert(@type_map_cache.known_coder_type_records.empty?)
          end
        end
      end
    end
  end
end
