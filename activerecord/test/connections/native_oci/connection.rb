print "Using OCI Oracle\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new STDOUT
ActiveRecord::Base.logger.level = Logger::WARN

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => 'oci',
  :host     => '',          # can use an oracle SID
  :username => 'arunit',
  :password => 'arunit',
  :database => db1
)

Course.establish_connection(
  :adapter  => 'oci',
  :host     => '',          # can use an oracle SID
  :username => 'arunit2',
  :password => 'arunit2',
  :database => db2
)
