print "Using native SQlite\n"
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

sqlite_test_db = File.dirname(__FILE__) + "/../../fixtures/fixture_database.sqlite"

if File.exist?(sqlite_test_db)
  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite",
    :dbfile  => sqlite_test_db
  )
else
  puts "*** You must create the SQLite test database in: #{sqlite_test_db} ***"
  exit!
end
