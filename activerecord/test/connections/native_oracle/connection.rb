# uses oracle_enhanced adapter in ENV['ORACLE_ENHANCED_PATH'] or from github.com/rsim/oracle-enhanced.git
require 'active_record/connection_adapters/oracle_enhanced_adapter'

# otherwise failed with silence_warnings method missing exception
require 'active_support/core_ext/kernel/reporting'

print "Using Oracle\n"
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

# Set these to your database connection strings
ENV['ARUNIT_DB_NAME'] ||= 'orcl'

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'oracle_enhanced',
    :database => ENV['ARUNIT_DB_NAME'],
    :username => 'arunit',
    :password => 'arunit',
    :emulate_oracle_adapter => true
  },
  'arunit2' => {
    :adapter  => 'oracle_enhanced',
    :database => ENV['ARUNIT_DB_NAME'],
    :username => 'arunit2',
    :password => 'arunit2',
    :emulate_oracle_adapter => true
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'

