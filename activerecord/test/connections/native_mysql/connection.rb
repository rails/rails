print "Using native MySQL\n"
require_dependency 'fixtures/course'
require 'logger'

RAILS_DEFAULT_LOGGER = Logger.new('debug.log')
RAILS_DEFAULT_LOGGER.level = Logger::DEBUG
ActiveRecord::Base.logger = RAILS_DEFAULT_LOGGER

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'mysql',
    :username => 'rails',
    :encoding => 'utf8',
    :database => 'activerecord_unittest',
  },
  'arunit2' => {
    :adapter  => 'mysql',
    :username => 'rails',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
