puts 'Using native Frontbase'
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter => 'frontbase',
    :host => 'localhost',
    :username => 'rails',
    :password => '',
    :database => 'activerecord_unittest',
    :session_name => "unittest-#{$$}"
  },
  'arunit2' => {
    :adapter => 'frontbase',
    :host => 'localhost',
    :username => 'rails',
    :password => '',
    :database => 'activerecord_unittest2',
    :session_name => "unittest-#{$$}"
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
