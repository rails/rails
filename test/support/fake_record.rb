module FakeRecord
  class Column < Struct.new(:name, :type)
  end

  class Connection
    attr_reader :tables

    def initialize
      @tables = %w{ users photos developers }
      @columns = {
        'users' => [
          Column.new('id', :integer),
          Column.new('name', :string),
          Column.new('bool', :boolean),
          Column.new('created_at', :date),
        ]
      }
      @primary_keys = {
        'users' => 'id'
      }
    end

    def primary_key name
      @primary_keys[name.to_s]
    end

    def table_exists? name
      @tables.include? name.to_s
    end

    def columns name, message = nil
      @columns[name.to_s]
    end

    def quote_table_name name
      "\"#{name.to_s}\""
    end

    def quote_column_name name
      "\"#{name.to_s}\""
    end

    def quote thing, column = nil
      if column && column.type == :integer
        return 'NULL' if thing.nil?
        return thing.to_i
      end

      case thing
      when true
        "'t'"
      when false
        "'f'"
      when nil
        'NULL'
      when Numeric
        thing
      else
        "'#{thing}'"
      end
    end
  end

  class ConnectionPool
    class Spec < Struct.new(:config)
    end

    attr_reader :spec, :connection

    def initialize
      @spec = Spec.new(:adapter => 'america')
      @connection = Connection.new
    end

    def with_connection
      yield connection
    end
  end

  class Base
    attr_accessor :connection_pool

    def initialize
      @connection_pool = ConnectionPool.new
    end

    def connection
      connection_pool.connection
    end
  end
end
