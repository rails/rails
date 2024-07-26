print "Using native SQlite\n"
require 'fixtures/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

base = "#{File.dirname(__FILE__)}/../../fixtures"
sqlite_test_db  = "#{base}/fixture_database.sqlite"
sqlite_test_db2 = "#{base}/fixture_database_2.sqlite"

[sqlite_test_db, sqlite_test_db2].each do |db|
  unless File.exist?(db) and File.size(db) > 0
    puts "*** You must create the SQLite test database in: #{db} ***"
    exit!
  else
    puts "OK: #{db}"
  end
end

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite",
  :dbfile  => sqlite_test_db)
Course.establish_connection(
  :adapter => "sqlite",
  :dbfile  => sqlite_test_db2)
