# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    module PostgreSQL
      class TypeMapCache
        include Singleton

        attr_accessor :additional_type_records
        attr_accessor :known_coder_type_records

        def initialize
          @additional_type_records = []
          @known_coder_type_records = []
        end

        class << self
          def init(schema_cache)
            return if schema_cache.nil? || !schema_cache.is_a?(PostgreSQL::SchemaCache)

            self.instance.known_coder_type_records = schema_cache.known_coder_type_records
            self.instance.additional_type_records = schema_cache.additional_type_records
          end

          def clear
            self.instance.additional_type_records = []
            self.instance.known_coder_type_records = []
          end
        end
      end
    end
  end
end
