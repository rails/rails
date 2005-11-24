print "Using native SQLServer via ODBC\n"
require_dependency 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

dsn1 = 'activerecord_unittest'
dsn2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "sqlserver",
  :mode     => "ODBC",
  :host     => "localhost",
  :username => "sa",
  :password => "",
  :dsn => dsn1
)

Course.establish_connection(
  :adapter  => "sqlserver",
  :mode     => "ODBC",
  :host     => "localhost",
  :username => "sa",
  :password => "",
  :dsn => dsn2
)
