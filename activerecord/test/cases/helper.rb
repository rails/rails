$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'config'
require 'test/unit'

require 'active_record'
require 'active_record/fixtures'
require 'active_record/test_case'
require 'connection'

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

def uses_mocha(description)
  require 'rubygems'
  require 'mocha'
  yield
rescue LoadError
  $stderr.puts "Skipping #{description} tests. `gem install mocha` and try again."
end

ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/]

  def execute_with_query_record(sql, name = nil, &block)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_query_record(sql, name, &block)
  end

  alias_method_chain :execute, :query_record
end

# Make with_scope public for tests
class << ActiveRecord::Base
  public :with_scope, :with_exclusive_scope
end

unless ENV['FIXTURE_DEBUG']
  module Test #:nodoc:
    module Unit #:nodoc:
      class << TestCase #:nodoc:
        def try_to_load_dependency_with_silence(*args)
          ActiveRecord::Base.logger.silence { try_to_load_dependency_without_silence(*args)}
        end

        alias_method_chain :try_to_load_dependency, :silence
      end
    end
  end
end