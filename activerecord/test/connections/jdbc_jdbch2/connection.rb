print "Using H2 via JRuby, activerecord-jdbc-adapter and activerecord-jdbch2-adapter\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'jdbch2',
    :database => 'activerecord_unittest'
  },
  'arunit2' => {
    :adapter  => 'jdbch2',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
