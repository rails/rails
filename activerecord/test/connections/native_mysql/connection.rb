print "Using native MySQL\n"
require 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql",
  :host     => "localhost",
  :username => "rails",
  :password => "",
  :database => db1
)

Course.establish_connection(
  :adapter  => "mysql",
  :host     => "localhost",
  :username => "rails",
  :password => "",
  :database => db2
)
