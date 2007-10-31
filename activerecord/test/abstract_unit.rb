$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')

require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'active_support/test_case'
require 'connection'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true


QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name('type') unless Object.const_defined?(:QUOTED_TYPE)

class Test::Unit::TestCase #:nodoc:
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/"
  self.use_instantiated_fixtures = false
  self.use_transactional_fixtures = (ENV['AR_NO_TX_FIXTURES'] != "yes")

  def create_fixtures(*table_names, &block)
    Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures/", table_names, {}, &block)
  end

  def assert_date_from_db(expected, actual, message = nil)
    # SQL Server doesn't have a separate column type just for dates,
    # so the time is in the string and incorrectly formatted
    if current_adapter?(:SQLServerAdapter)
      assert_equal expected.strftime("%Y/%m/%d 00:00:00"), actual.strftime("%Y/%m/%d 00:00:00")
    elsif current_adapter?(:SybaseAdapter)
      assert_equal expected.to_s, actual.to_date.to_s, message
    else
      assert_equal expected.to_s, actual.to_s, message
    end
  end

  def assert_queries(num = 1)
    $query_count = 0
    yield
  ensure
    assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
end

def current_adapter?(*types)
  types.any? do |type|
    ActiveRecord::ConnectionAdapters.const_defined?(type) &&
      ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
  end
end

def uses_mocha(test_name)
  require 'rubygems'
  require 'mocha'
  yield
rescue LoadError
  $stderr.puts "Skipping #{test_name} tests. `gem install mocha` and try again."
end

ActiveRecord::Base.connection.class.class_eval do
  unless defined? IGNORED_SQL
    IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/]

    def execute_with_counting(sql, name = nil, &block)
      $query_count ||= 0
      $query_count  += 1 unless IGNORED_SQL.any? { |r| sql =~ r }
      execute_without_counting(sql, name, &block)
    end

    alias_method_chain :execute, :counting
  end
end

# Make with_scope public for tests
class << ActiveRecord::Base
  public :with_scope, :with_exclusive_scope
end

#ActiveRecord::Base.logger = Logger.new(STDOUT)
#ActiveRecord::Base.colorize_logging = false
