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

# for assert_queries test helper
ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SELECT_SQL = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from ((all|user)_tab_columns|(all|user)_triggers|(all|user)_constraints)/im]

  def select_with_query_record(sql, name = nil, return_column_names = false)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SELECT_SQL.any? { |r| sql =~ r }
    select_without_query_record(sql, name, return_column_names)
  end

  alias_method_chain :select, :query_record
end
