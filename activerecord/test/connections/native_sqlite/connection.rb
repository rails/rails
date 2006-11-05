print "Using native SQlite\n"
require_dependency 'fixtures/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

BASE_DIR = File.expand_path(File.dirname(__FILE__) + '/../../fixtures')
sqlite_test_db  = "#{BASE_DIR}/fixture_database.sqlite"
sqlite_test_db2 = "#{BASE_DIR}/fixture_database_2.sqlite"

def make_connection(clazz, db_file)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'sqlite', :database => db_file } }
  unless File.exist?(db_file)
    puts "SQLite database not found at #{db_file}. Rebuilding it."
    sqlite_command = %Q{sqlite #{db_file} "create table a (a integer); drop table a;"}
    puts "Executing '#{sqlite_command}'"
    raise SqliteError.new("Seems that there is no sqlite executable available") unless system(sqlite_command)
  end
  clazz.establish_connection(clazz.name)
end

make_connection(ActiveRecord::Base, sqlite_test_db)
make_connection(Course, sqlite_test_db2)
