print "Using native Firebird\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "firebird",
  :host     => "localhost",
  :username => "rails",
  :password => "rails",
  :database => db1
)

Course.establish_connection(
  :adapter  => "firebird",
  :host     => "localhost",
  :username => "rails",
  :password => "rails",
  :database => db2
)
