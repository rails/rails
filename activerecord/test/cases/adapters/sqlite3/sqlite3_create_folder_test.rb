# encoding: utf-8
require "cases/helper"
require 'models/owner'

module ActiveRecord
  module ConnectionAdapters
    class SQLite3CreateFolder < ActiveRecord::TestCase
      def test_sqlite_creates_directory
        Dir.mktmpdir do |dir|
          dir = Pathname.new(dir)
          @conn = Base.sqlite3_connection :database => dir.join("db/foo.sqlite3"),
                               :adapter => 'sqlite3',
                               :timeout => 100

          assert Dir.exists? dir.join('db')
          assert File.exist? dir.join('db/foo.sqlite3')
        end
      end
    end
  end
end
