# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCache < ActiveRecord::ConnectionAdapters::SchemaCache
        attr_accessor :additional_type_records, :known_coder_type_records

        def initialize(conn)
          super(conn)

          @additional_type_records = PostgreSQL::TypeMapCache.instance.additional_type_records || []
          @known_coder_type_records = PostgreSQL::TypeMapCache.instance.known_coder_type_records || []
        end

        def encode_with(coder)
          super

          coder["additional_type_records"] = @additional_type_records
          coder["known_coder_type_records"] = @known_coder_type_records
        end

        def init_with(coder)
          @additional_type_records = coder["additional_type_records"]
          @known_coder_type_records = coder["known_coder_type_records"]

          super
        end

        def marshal_dump
          reset_version!

          [@version, @columns, {}, @primary_keys, @data_sources, @indexes, database_version, @known_coder_type_records, @additional_type_records]
        end

        def marshal_load(array)
          @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, @database_version, @known_coder_type_records, @additional_type_records = array
          @indexes ||= {}

          derive_columns_hash_and_deduplicate_values
        end
      end
    end
  end
end
