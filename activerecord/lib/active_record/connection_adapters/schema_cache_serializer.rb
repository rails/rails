# frozen_string_literal: true

# :markup: markdown

json_min_version = "2.10.0"

begin
  gem "json", ">= #{json_min_version}"
rescue LoadError
  raise LoadError, <<~MSG
    JSON schema cache format requires json gem version #{json_min_version} or later.
    Please add it to your Gemfile:
      gem "json", ">= #{json_min_version}"
  MSG
end

require "json"

module ActiveRecord
  module ConnectionAdapters
    class JSONSchemaCacheSerializer # :nodoc:
      REGISTRY = {
        "column" => "ActiveRecord::ConnectionAdapters::Column",
        "index" => "ActiveRecord::ConnectionAdapters::IndexDefinition",
        "schema_cache" => "ActiveRecord::ConnectionAdapters::SchemaCache",
        "sql_type_metadata" => "ActiveRecord::ConnectionAdapters::SqlTypeMetadata",

        "date" => "ActiveRecord::Type::Date",
        "datetime" => "ActiveRecord::Type::DateTime",
        "decimal_without_scale" => "ActiveRecord::Type::DecimalWithoutScale",
        "json" => "ActiveRecord::Type::Json",
        "text" => "ActiveRecord::Type::Text",
        "time" => "ActiveRecord::Type::Time",
        "unsigned_integer" => "ActiveRecord::Type::UnsignedInteger",

        "binary"  => "ActiveModel::Type::Binary",
        "boolean" => "ActiveModel::Type::Boolean",
        "decimal" => "ActiveModel::Type::Decimal",
        "float" => "ActiveModel::Type::Float",
        "immutable_string" => "ActiveModel::Type::ImmutableString",
        "integer" => "ActiveModel::Type::Integer",
        "string"  => "ActiveModel::Type::String",
        "value" => "ActiveModel::Type::Value",

        "mysql_column" => "ActiveRecord::ConnectionAdapters::MySQL::Column",
        "mysql_index_definition" => "ActiveRecord::ConnectionAdapters::MySQL::IndexDefinition",
        "mysql_type_metadata" => "ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata",

        "sqlite3_column" => "ActiveRecord::ConnectionAdapters::SQLite3::Column",
        "sqlite3_integer" => "ActiveRecord::ConnectionAdapters::SQLite3Adapter::SQLite3Integer",

        "postgresql_column" => "ActiveRecord::ConnectionAdapters::PostgreSQL::Column",
        "postgresql_type_metadata" => "ActiveRecord::ConnectionAdapters::PostgreSQL::TypeMetadata",

        "postgresql_array" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array",
        "postgresql_bit" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Bit",
        "postgresql_bit_varying" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::BitVarying",
        "postgresql_bytea" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Bytea",
        "postgresql_cidr" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Cidr",
        "postgresql_date" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Date",
        "postgresql_date_time" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::DateTime",
        "postgresql_decimal" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Decimal",
        "postgresql_enum" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Enum",
        "postgresql_hstore" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Hstore",
        "postgresql_inet" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Inet",
        "postgresql_interval" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Interval",
        "postgresql_jsonb" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Jsonb",
        "postgresql_legacy_point" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::LegacyPoint",
        "postgresql_macaddr" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Macaddr",
        "postgresql_money" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Money",
        "postgresql_oid" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Oid",
        "postgresql_point" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Point",
        "postgresql_range" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Range",
        "postgresql_specialized_string" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::SpecializedString",
        "postgresql_timestamp" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Timestamp",
        "postgresql_timestamp_with_time_zone" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::TimestampWithTimeZone",
        "postgresql_uuid" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid",
        "postgresql_vector" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Vector",
        "postgresql_xml" => "ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Xml",
      }.freeze

      @class_registry = {}
      @type_registry = REGISTRY.invert

      class << self
        def register(type, klass)
          @class_registry[type] = klass
          @type_registry[klass.name] = type
        end

        def class_for(type)
          @class_registry[type] ||= Object.const_get(REGISTRY.fetch(type))
        end

        def type_for(klass)
          @type_registry.fetch(klass.name)
        end

        def dump(cache)
          objects = {}.compare_by_identity
          references = []
          coder = JSON::Coder.new do |object, _is_key|
            unless object.respond_to?(:as_schema_json)
              raise ArgumentError, "Cannot serialize #{object.class} to JSON schema cache."
            end

            objects[object] ||= begin
              data = object.as_schema_json
              data.compact!
              data["_type"] = type_for(object.class)
              references << coder.dump(data)
              references.size - 1
            end
          end
          coder.dump(cache)
          JSON.dump(references.map { |d| JSON::Fragment.new(d) })
        end

        def load(data)
          objects = []
          JSON.parse(data).each do |object|
            klass = class_for(object.fetch("_type"))
            instance = klass.allocate
            instance.init_from_schema_json(object, objects)
            objects << instance
          end
          objects.last
        end
      end
    end
  end
end
