print "Using native SQLServer\n"
require 'fixtures/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.establish_connection(
  :adapter  => "sqlserver",
  :dsn => "DBI:ADO:Provider=SQLOLEDB;Data Source=(local);Initial Catalog=test;User Id=sa;Password=password;"
)

Course.establish_connection(
  :adapter => "sqlserver",
  :dsn => "DBI:ADO:Provider=SQLOLEDB;Data Source=(local);Initial Catalog=test2;User Id=sa;Password=password;"
)
