# gem "rsim-activerecord-oracle_enhanced-adapter"
# gem "activerecord-oracle_enhanced-adapter", ">=1.2.1"
# uses local copy of oracle_enhanced adapter
$:.unshift("../../oracle-enhanced/lib")
require 'active_record/connection_adapters/oracle_enhanced_adapter'
# gem "activerecord-jdbc-adapter"
# require 'active_record/connection_adapters/jdbc_adapter'

# otherwise failed with silence_warnings method missing exception
require 'active_support/core_ext/kernel/reporting'

print "Using Oracle\n"
require_dependency 'models/course'
require 'logger'

# ActiveRecord::Base.logger = Logger.new STDOUT
# ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.logger = Logger.new("debug.log")

# Set these to your database connection strings
db = ENV['ARUNIT_DB_NAME'] = 'orcl'

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'oracle_enhanced',
    :database => db,
    :host => "localhost", # used just by JRuby to construct JDBC connect string
    # :adapter => "jdbc",
    # :driver => "oracle.jdbc.driver.OracleDriver",
    # :url => "jdbc:oracle:thin:@localhost:1521:#{db}",
    :username => 'arunit',
    :password => 'arunit',
    :emulate_oracle_adapter => true
  },
  'arunit2' => {
    :adapter  => 'oracle_enhanced',
    :database => db,
    :host => "localhost", # used just by JRuby to construct JDBC connect string
    # :adapter => "jdbc",
    # :driver => "oracle.jdbc.driver.OracleDriver",
    # :url => "jdbc:oracle:thin:@localhost:1521:#{db}",
    :username => 'arunit2',
    :password => 'arunit2',
    :emulate_oracle_adapter => true
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'

# ActiveRecord::Base.connection.execute %q{alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS'}
# ActiveRecord::Base.connection.execute %q{alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS'} rescue nil

# for assert_queries test helper
ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SELECT_SQL = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^\s*select .* from all_tab_columns/im]

  def select_with_query_record(sql, name = nil, return_column_names = false)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SELECT_SQL.any? { |r| sql =~ r }
    select_without_query_record(sql, name, return_column_names)
  end

  alias_method_chain :select, :query_record
end

# For JRuby Set default $KCODE to UTF8
$KCODE = "UTF8" if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
