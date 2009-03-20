$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activerecord/lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'config'
require 'active_model'

require 'active_record'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

# Setup database connection
db_file = "#{FIXTURES_ROOT}/fixture_database.sqlite3"
ActiveRecord::Base.configurations = { ActiveRecord::Base.name => { :adapter => 'sqlite3', :database => db_file, :timeout => 5000 } }
unless File.exist?(db_file)
  puts "SQLite3 database not found at #{db_file}. Rebuilding it."
  sqlite_command = %Q{sqlite3 "#{db_file}" "create table a (a integer); drop table a;"}
  puts "Executing '#{sqlite_command}'"
  raise SqliteError.new("Seems that there is no sqlite3 executable available") unless system(sqlite_command)
end
ActiveRecord::Base.establish_connection(ActiveRecord::Base.name)

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'rubygems'
require 'test/unit'
gem 'mocha', '>= 0.9.5'
require 'mocha'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end
