# gem "rsim-activerecord-oracle_enhanced-adapter"
# gem "activerecord-oracle_enhanced-adapter"
# uses local copy of oracle_enhanced adapter
$:.unshift("../../oracle-enhanced/lib")
require 'active_record/connection_adapters/oracle_enhanced_adapter'

print "Using Oracle\n"
require_dependency 'models/course'
require 'logger'

# ActiveRecord::Base.logger = Logger.new STDOUT
# ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.logger = Logger.new("debug.log")

# Set these to your database connection strings
db = ENV['ARUNIT_DB'] || 'XE'

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'oracle_enhanced',
    :database => db,
    :host => "arunit", # used just by JRuby to construct JDBC connect string
    :username => 'arunit',
    :password => 'arunit',
    :emulate_oracle_adapter => true
  },
  'arunit2' => {
    :adapter  => 'oracle_enhanced',
    :database => db,
    :host => "arunit", # used just by JRuby to construct JDBC connect string
    :username => 'arunit2',
    :password => 'arunit2',
    :emulate_oracle_adapter => true
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
