print "Using native PostgreSQL\n"
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")
ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => "localhost", 
  :username => "postgres",
  :password => "postgres", 
  :database => "activerecord_unittest"
)
