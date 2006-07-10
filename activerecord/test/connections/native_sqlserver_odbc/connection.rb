print "Using native SQLServer via ODBC\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'sqlserver',
    :mode     => 'ODBC',
    :host     => 'localhost',
    :username => 'sa',
    :dsn => 'activerecord_unittest'
  },
  'arunit2' => {
    :adapter  => 'sqlserver',
    :mode     => 'ODBC',
    :host     => 'localhost',
    :username => 'sa',
    :dsn => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
