print "Using native SQLite3\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

BASE_DIR = FIXTURES_ROOT
sqlite_test_db  = "#{BASE_DIR}/fixture_database.sqlite3"
sqlite_test_db2 = "#{BASE_DIR}/fixture_database_2.sqlite3"

def make_connection(clazz, db_file)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'sqlite3', :database => db_file, :timeout => 5000 } }
  clazz.establish_connection(clazz.name)
end

make_connection(ActiveRecord::Base, sqlite_test_db)
make_connection(Course, sqlite_test_db2)
