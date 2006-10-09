print "Using native SQLite3\n"
require_dependency 'fixtures/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

BASE_DIR = File.expand_path(File.dirname(__FILE__) + '/../../fixtures')
sqlite_test_db  = "#{BASE_DIR}/fixture_database.sqlite3"
sqlite_test_db2 = "#{BASE_DIR}/fixture_database_2.sqlite3"

def make_connection(clazz, db_file, db_definitions_file)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'sqlite3', :database => db_file, :timeout => 5000 } }
  unless File.exist?(db_file)
    puts "SQLite3 database not found at #{db_file}. Rebuilding it."
    sqlite_command = %Q{sqlite3 #{db_file} "create table a (a integer); drop table a;"}
    puts "Executing '#{sqlite_command}'"
    raise SqliteError.new("Seems that there is no sqlite3 executable available") unless system(sqlite_command)
    clazz.establish_connection(clazz.name)
    script = File.read("#{BASE_DIR}/db_definitions/#{db_definitions_file}")
    # SQLite-Ruby has problems with semi-colon separated commands, so split and execute one at a time
    script.split(';').each do
      |command|
      clazz.connection.execute(command) unless command.strip.empty?
    end
  else
    clazz.establish_connection(clazz.name)
  end
end

make_connection(ActiveRecord::Base, sqlite_test_db, 'sqlite.sql')
make_connection(Course, sqlite_test_db2, 'sqlite2.sql')
load(File.join(BASE_DIR, 'db_definitions', 'schema.rb'))
