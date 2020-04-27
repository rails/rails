# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCache < ConnectionAdapters::SchemaCache # :nodoc:
        attr_accessor :additional_type_records, :known_coder_type_records

        def initialize(conn)
          @additional_type_records = {}
          @known_coder_type_records = []
          super
        end

        def encode_with(coder)
          super
          reset_type_records!
          coder["additional_type_records"]  = @additional_type_records
          coder["known_coder_type_records"] = @known_coder_type_records
        end

        def init_with(coder)
          super
          @additional_type_records  = coder["additional_type_records"]
          @known_coder_type_records = coder["known_coder_type_records"]
        end

        def marshal_dump
          reset_type_records!
          super + [@additional_type_records, @known_coder_type_records]
        end

        def marshal_load(array)
          @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, @database_version, @additional_type_records, @known_coder_type_records = array
          @indexes ||= {}

          derive_columns_hash_and_deduplicate_values
          push_type_records_cache!
        end

        def clear!
          super
          reset_type_records!
        end

        private
          def derive_columns_hash_and_deduplicate_values
            super
            @additional_type_records ||= {}
            @additional_type_records = deep_deduplicate(@additional_type_records)

            @known_coder_type_records ||= []
            @known_coder_type_records = deep_deduplicate(@known_coder_type_records)
          end

          def reset_type_records!
            # handling for cases of a SchemaCache w/out a connection (ie. when it's first loaded)
            @connection ||= nil
            return unless @connection.is_a?(ConnectionAdapters::SchemaCache)

            @additional_type_records = @connection.class&.additional_type_records_cache
            @known_coder_type_records = @connection.class&.known_coder_type_records_cache
          end

          def push_type_records_cache!
            # handling for cases of a SchemaCache w/out a connection (ie. when it's first loaded)
            @connection ||= nil
            return unless @connection.is_a?(ConnectionAdapters::SchemaCache)

            @connection.class&.additional_type_records_cache = @additional_type_records
            @connection.class&.known_coder_type_records_cache = @known_coder_type_records
          end
      end
    end
  end
end
