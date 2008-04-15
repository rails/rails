module Fake
  class Engine
    def connection
      @conn ||= Connection.new
    end
  end

  class Connection
    include ActiveRecord::ConnectionAdapters::Quoting
  
    def columns(table_name, comment)
      { "users" =>
        [
          Column.new("id", :integer),
          Column.new("name", :string)
        ],
      "photos" =>
        [
          Column.new("id", :integer),
          Column.new("user_id", :integer),
          Column.new("camera_id", :integer)
        ]
      }[table_name]
    end

    def select_all(*args)
      []
    end
  
    def quote_column_name(column_name)
      "`#{column_name}`"
    end

    def quote_table_name(table_name)
      "`#{table_name}`"
    end
  end

  class Column
    attr_reader :name, :type
  
    def initialize(name, type)
      @name = name
      @type = type
    end
  end
end