# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCache < ActiveRecord::ConnectionAdapters::SchemaCache
        attr_reader :postgresql_additional_type_records, :postgresql_known_coder_type_records

        def encode_with(coder)
          super
          reset_postgresql_type_records!
          coder["postgresql_additional_type_records"] = @postgresql_additional_type_records
          coder["postgresql_known_coder_type_records"] = @postgresql_known_coder_type_records
        end

        def init_with(coder)
          @postgresql_additional_type_records = coder["postgresql_additional_type_records"]
          @postgresql_known_coder_type_records = coder["postgresql_known_coder_type_records"]
          super
        end

        def clear!
          super
          @postgresql_additional_type_records = []
          @postgresql_known_coder_type_records = []
        end

        def marshal_dump
          reset_version!
          reset_postgresql_type_records!
          [@version, @columns, {}, @primary_keys, @data_sources, @indexes, database_version, @postgresql_additional_type_records, @postgresql_known_coder_type_records]
        end

        def marshal_load(array)
          @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, @database_version, @postgresql_additional_type_records, @postgresql_known_coder_type_records = array
          @indexes ||= {}

          derive_columns_hash_and_deduplicate_values
        end

        private
          def reset_postgresql_type_records!
            @postgresql_additional_type_records = connection&.additional_type_records_cache
            @postgresql_known_coder_type_records = connection&.known_coder_type_records_cache
          end
      end
    end
  end
end
