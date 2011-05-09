gem 'activerecord-jdbcsqlite3-adapter'
require 'arjdbc/sqlite3'

module ActiveRecord::ConnectionAdapters
  class SQLiteAdapter < JdbcAdapter

    protected

    def last_inserted_id(result)
      last_insert_id
    end

  end
end
