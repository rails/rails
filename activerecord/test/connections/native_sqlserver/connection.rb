print "Using native SQLServer\n"
require 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.establish_connection(
  :adapter  => "sqlserver",
  :host     => "localhost",
  :username => "sa",
  :password => "",
  :database => db1
)

Course.establish_connection(
  :adapter  => "sqlserver",
  :host     => "localhost",
  :username => "sa",
  :password => "",
  :database => db2
)
