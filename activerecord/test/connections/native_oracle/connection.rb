print "Using native Oracle\n"
require 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'local'
db2 = 'local'

ActiveRecord::Base.establish_connection(
  :adapter  => "oracle",
  :host     => "localhost",
  :username => "arunit",
  :password => "arunit",
  :database => db1
)

Course.establish_connection(
  :adapter  => "oracle",
  :host     => "localhost",
  :username => "arunit2",
  :password => "arunit2",
  :database => db2
)
