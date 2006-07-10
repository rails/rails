print "Using native Sybase Open Client\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'sybase',
    :host     => 'database_ASE',
    :username => 'sa',
    :database => 'activerecord_unittest'
  },
  'arunit2' => {
    :adapter  => 'sybase',
    :host     => 'database_ASE',
    :username => 'sa',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
