require File.expand_path('../../../../load_paths', __FILE__)

require 'config'

require 'test/unit'
require 'stringio'
require 'mocha/setup'

require 'active_record'
require 'active_support/dependencies'

require 'support/config'
require 'support/connection'

ARTest.connect

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Quote "type" if it's a reserved word for the current connection.
QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name('type')

def current_adapter?(*types)
  types.any? do |type|
    ActiveRecord::ConnectionAdapters.const_defined?(type) &&
      ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
  end
end

ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /SHOW FIELDS/]

  def execute_with_query_record(sql, name = nil, &block)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_query_record(sql, name, &block)
  end

  alias_method_chain :execute, :query_record
end

# Oracle specific ignored SQLs
ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SELECT_SQL = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from ((all|user)_tab_columns|(all|user)_triggers|(all|user)_constraints)/im]

  def select_with_query_record(sql, name = nil)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SELECT_SQL.any? { |r| sql =~ r }
    select_without_query_record(sql, name)
  end

  alias_method_chain :select, :query_record
end if ENV['ARCONN'] == 'oracle'

ActiveRecord::Base.connection.class.class_eval {
  attr_accessor :column_calls, :column_calls_by_table

  def columns_with_calls(*args)
    @column_calls ||= 0
    @column_calls_by_table ||= Hash.new {|h,table| h[table] = 0}

    @column_calls += 1
    @column_calls_by_table[args.first.to_s] += 1
    columns_without_calls(*args)
  end

  alias_method_chain :columns, :calls
}

unless ENV['FIXTURE_DEBUG']
  module ActiveRecord::TestFixtures::ClassMethods
    def try_to_load_dependency_with_silence(*args)
      ActiveRecord::Base.logger.silence { try_to_load_dependency_without_silence(*args)}
    end

    alias_method_chain :try_to_load_dependency, :silence
  end
end

require "cases/validations_repair_helper"
class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include ActiveRecord::ValidationsRepairHelper

  self.fixture_path = FIXTURES_ROOT
  self.use_instantiated_fixtures  = false
  self.use_transactional_fixtures = true

  def create_fixtures(*table_names, &block)
    Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names, {}, &block)
  end
end

# silence verbose schema loading
original_stdout = $stdout
$stdout = StringIO.new

begin
  adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
  adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

  load SCHEMA_ROOT + "/schema.rb"

  if File.exists?(adapter_specific_schema_file)
    load adapter_specific_schema_file
  end
ensure
  $stdout = original_stdout
end
