print "Using native DB2\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter => 'db2',
    :host => 'localhost',
    :username => 'arunit',
    :password => 'arunit',
    :database => 'arunit'
  },
  'arunit2' => {
    :adapter => 'db2',
    :host => 'localhost',
    :username => 'arunit',
    :password => 'arunit',
    :database => 'arunit2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
