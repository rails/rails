print "Using Derby via JRuby, activerecord-jdbc-adapter and activerecord-jdbcderby-adapter\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'jdbcderby',
    :database => 'activerecord_unittest'
  },
  'arunit2' => {
    :adapter  => 'jdbcderby',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
