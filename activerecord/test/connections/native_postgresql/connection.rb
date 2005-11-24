print "Using native PostgreSQL\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :username => "postgres",
  :password => "postgres", 
  :database => db1,
  :min_messages => "warning"
)

Course.establish_connection(
  :adapter  => "postgresql",
  :username => "postgres",
  :password => "postgres", 
  :database => db2,
  :min_messages => "warning"
)
