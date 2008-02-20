print "Using native PostgreSQL\n"
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'postgresql',
    :database => 'activerecord_unittest',
    :min_messages => 'warning'
  },
  'arunit2' => {
    :adapter  => 'postgresql',
    :database => 'activerecord_unittest2',
    :min_messages => 'warning'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
