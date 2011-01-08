# This file connects to an in-memory SQLite3 database, which is a very fast way to run the tests.
# The downside is that disconnect from the database results in the database effectively being
# wiped. For this reason, pooled_connections_test.rb is disabled when using an in-memory database.

print "Using native SQLite3 (in memory)\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

def make_connection(clazz)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'sqlite3', :database  => ':memory:' } }
  clazz.establish_connection(clazz.name)
end

make_connection(ActiveRecord::Base)
make_connection(Course)
