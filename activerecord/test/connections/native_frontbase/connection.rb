puts 'Using native Frontbase'
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter      => "frontbase",
  :host         => "localhost",
  :username     => "rails",
  :password     => "",
  :database     => db1,
  :session_name => "unittest-#{$$}"
)

Course.establish_connection(
  :adapter      => "frontbase",
  :host         => "localhost",
  :username     => "rails",
  :password     => "",
  :database     => db2,
  :session_name => "unittest-#{$$}"
)
