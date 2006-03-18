print "Using native OpenBase\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "openbase",
  :username => "admin",
  :password => "", 
  :database => db1
)

Course.establish_connection(
  :adapter  => "openbase",
  :username => "admin",
  :password => "", 
  :database => db2
)
