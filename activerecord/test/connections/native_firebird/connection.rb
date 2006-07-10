print "Using native Firebird\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter => 'firebird',
    :host => 'localhost',
    :username => 'rails',
    :password => 'rails',
    :database => 'activerecord_unittest',
    :charset => 'UTF8'
  },
  'arunit2' => {
    :adapter => 'firebird',
    :host => 'localhost',
    :username => 'rails',
    :password => 'rails',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
