class FakeDatabase
  def self.connection
    @@conn ||= FakeConnection.new
  end
end

class FakeConnection
  include ActiveRecord::ConnectionAdapters::Quoting
  
  def columns(table_name, comment)
    case table_name
    when "users"
      [
        FakeColumn.new("id", :integer),
        FakeColumn.new("name", :string)
      ]
    when "photos"
      [
        FakeColumn.new("id", :integer),
        FakeColumn.new("user_id", :integer),
        FakeColumn.new("camera_id", :integer)
      ]
    else
      raise "unknown table: #{table_name}"
    end
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

class FakeColumn
  attr_reader :name, :type
  
  def initialize(name, type)
    @name = name
    @type = type
  end
end