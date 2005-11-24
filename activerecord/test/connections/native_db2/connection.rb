print "Using native DB2\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'arunit'
db2 = 'arunit2'

ActiveRecord::Base.establish_connection(
  :adapter  => "db2",
  :host     => "localhost",
  :username => "arunit",
  :password => "arunit",
  :database => db1
)

Course.establish_connection(
  :adapter  => "db2",
  :host     => "localhost",
  :username => "arunit2",
  :password => "arunit2",
  :database => db2
)
