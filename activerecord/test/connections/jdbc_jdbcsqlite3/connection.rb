print "Using SQLite3 via JRuby, activerecord-jdbc-adapter and activerecord-jdbcsqlite3-adapter\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

BASE_DIR = FIXTURES_ROOT
sqlite_test_db  = "#{BASE_DIR}/fixture_database.sqlite3"
sqlite_test_db2 = "#{BASE_DIR}/fixture_database_2.sqlite3"

def make_connection(clazz, db_file)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'jdbcsqlite3', :database => db_file, :timeout => 5000 } }
  unless File.exist?(db_file)
    puts "SQLite3 database not found at #{db_file}. Rebuilding it."
    sqlite_command = %Q{sqlite3 "#{db_file}" "create table a (a integer); drop table a;"}
    puts "Executing '#{sqlite_command}'"
    raise SqliteError.new("Seems that there is no sqlite3 executable available") unless system(sqlite_command)
  end
  clazz.establish_connection(clazz.name)
end

make_connection(ActiveRecord::Base, sqlite_test_db)
make_connection(Course, sqlite_test_db2)
