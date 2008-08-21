print "Using native MySQL\n"
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

# GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'localhost';
# GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'localhost';

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
