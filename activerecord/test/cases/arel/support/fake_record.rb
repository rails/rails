# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "date"

module FakeRecord
  class Column < Struct.new(:name, :type)
  end

  class Connection
    attr_reader :tables
    attr_accessor :visitor

    def initialize
      @tables = %w{ users photos developers products}
      @columns = {
        "users" => [
          Column.new("id", :integer),
          Column.new("name", :string),
          Column.new("bool", :boolean),
          Column.new("created_at", :date)
        ],
        "products" => [
          Column.new("id", :integer),
          Column.new("price", :decimal)
        ]
      }
      @columns_hash = {
        "users" => @columns["users"].index_by(&:name),
        "products" => @columns["products"].index_by(&:name)
      }
      @primary_keys = {
        "users" => "id",
        "products" => "id"
      }
      @visitor = Arel::Visitors::ToSql.new(self)
    end

    def columns_hash(table_name)
      @columns_hash[table_name]
    end

    def primary_key(name)
      @primary_keys[name.to_s]
    end

    def data_source_exists?(name)
      @tables.include? name.to_s
    end

    def columns(name, message = nil)
      @columns[name.to_s]
    end

    def quote_table_name(name)
      "\"#{name}\""
    end

    def quote_column_name(name)
      "\"#{name}\""
    end

    def sanitize_as_sql_comment(comment)
      comment
    end

    def schema_cache
      self
    end

    def quote(thing)
      case thing
      when DateTime
        "'#{thing.strftime("%Y-%m-%d %H:%M:%S")}'"
      when Date
        "'#{thing.strftime("%Y-%m-%d")}'"
      when true
        "'t'"
      when false
        "'f'"
      when nil
        "NULL"
      when Numeric
        thing
      else
        "'#{thing.to_s.gsub("'", "\\\\'")}'"
      end
    end

    def cast_bound_value(thing)
      thing
    end
  end

  class ConnectionPool
    def initialize
      @connection = Connection.new
    end

    def lease_connection
      @connection
    end

    def with_connection
      yield @connection
    end

    def table_exists?(name)
      @connection.tables.include? name.to_s
    end

    def columns_hash
      @connection.columns_hash
    end

    def schema_cache
      @connection
    end

    def quote(thing)
      @connection.quote thing
    end
  end

  class Base
    attr_accessor :connection_pool

    def initialize
      @connection_pool = ConnectionPool.new
    end

    def with_connection(...)
      connection_pool.with_connection(...)
    end

    def lease_connection
      connection_pool.lease_connection
    end
  end
end
