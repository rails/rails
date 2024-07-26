print "Using native PostgreSQL\n"
require 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => nil, 
  :username => "postgres",
  :password => "postgres", 
  :database => db1
)

Course.establish_connection(
  :adapter  => "postgresql",
  :host     => nil, 
  :username => "postgres",
  :password => "postgres", 
  :database => db2
)