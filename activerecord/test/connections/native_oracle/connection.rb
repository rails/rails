print "Using Oracle\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new STDOUT
ActiveRecord::Base.logger.level = Logger::WARN

# Set these to your database connection strings
db = ENV['ARUNIT_DB'] || 'activerecord_unittest'

ActiveRecord::Base.establish_connection(
  :adapter  => 'oracle',
  :username => 'arunit',
  :password => 'arunit',
  :database => db
)

Course.establish_connection(
  :adapter  => 'oracle',
  :username => 'arunit2',
  :password => 'arunit2',
  :database => db
)
