# frozen_string_literal: true

require "cases/helper"
require "models/owner"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3CreateFolder < ActiveRecord::SQLite3TestCase
      def test_sqlite_creates_directory
        Dir.mktmpdir do |dir|
          dir = Pathname.new(dir)
          @conn = SQLite3Adapter.new(
            database: dir.join("db/foo.sqlite3"),
            adapter: "sqlite3",
            timeout: 100,
          )
          @conn.connect!

          assert Dir.exist? dir.join("db")
          assert File.exist? dir.join("db/foo.sqlite3")
        ensure
          @conn.disconnect! if @conn
        end
      end
    end
  end
end
