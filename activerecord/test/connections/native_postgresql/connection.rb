print "Using native PostgreSQL\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'postgresql',
    :username => 'postgres',
    :database => 'activerecord_unittest',
    :min_messages => 'warning'
  },
  'arunit2' => {
    :adapter  => 'postgresql',
    :username => 'postgres',
    :database => 'activerecord_unittest2',
    :min_messages => 'warning'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
