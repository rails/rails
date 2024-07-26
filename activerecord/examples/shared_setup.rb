# Be sure to change the mysql_connection details and create a database for the example

$: << File.dirname(__FILE__) + '/../lib'

require 'active_record'
require 'logger'; class Logger; def format_message(severity, timestamp, msg, progname) "#{msg}\n" end; end

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(
  :adapter  => "mysql", 
  :host     => "localhost", 
  :username => "root", 
  :password => "", 
  :database => "activerecord_examples"
)
