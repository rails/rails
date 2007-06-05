print "Using native SQLite3\n"
require_dependency 'fixtures/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

def make_connection(clazz, db_definitions_file)
  clazz.establish_connection(:adapter => 'sqlite3', :database  => ':memory:')
  File.read("#{File.dirname(__FILE__)}/../../fixtures/db_definitions/#{db_definitions_file}").split(';').each do |command|
    clazz.connection.execute(command) unless command.strip.empty?
  end
end

make_connection(ActiveRecord::Base, 'sqlite.sql')
make_connection(Course, 'sqlite2.sql')
load("#{File.dirname(__FILE__)}/../../fixtures/db_definitions/schema.rb")
