require 'active_support/deprecation'
require 'active_support/test_case'

ActiveSupport::Deprecation.warn('ActiveRecord::TestCase is deprecated, please use ActiveSupport::TestCase')
module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    def teardown
      SQLCounter.log.clear
    end

    def assert_date_from_db(expected, actual, message = nil)
      # SybaseAdapter doesn't have a separate column type just for dates,
      # so the time is in the string and incorrectly formatted
      if current_adapter?(:SybaseAdapter)
        assert_equal expected.to_s, actual.to_date.to_s, message
      else
        assert_equal expected.to_s, actual.to_s, message
      end
    end

    def assert_sql(*patterns_to_match)
      SQLCounter.clear_log
      yield
      SQLCounter.log
    ensure
      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless SQLCounter.log.any?{ |sql| pattern === sql }
      end
      assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map{ |p| p.inspect }.join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.join("\n")}"}"
    end

    def assert_queries(num = 1, options={})
      SQLCounter.clear_log
      yield
    ensure
      log = options[:ignore_none] ? SQLCounter.all_log : SQLCounter.log
      assert_equal num, log.size, "#{log.size} instead of #{num} queries were executed.#{log.size == 0 ? '' : "\nQueries:\n#{log.join("\n")}"}"
    end

    def assert_no_queries
      assert_queries 0, :ignore_none => true do
        yield
      end
    end

  end

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :all_log
    end

    self.log = []
    self.all_log = []

    self.ignored_sql = [/^PRAGMA (?!(table_info))/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/, /^BEGIN/, /^COMMIT/]

    # FIXME: these need to be refactored so specific database can add their own
    # ignored SQL.
    # This ignored SQL is for Oracle.
    ignored_sql.concat [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im]
    # This ignored is for PostgreSQL.
    ignored_sql.concat [/^\s*select\b.*\bfrom\b.*pg_namespace\b/im, /^\s*select\b.*\battname\b.*\bfrom\b.*\bpg_attribute\b/im]

    def self.clear_log
      self.log = []
      self.all_log = []
    end

    attr_reader :ignore

    def initialize(ignore = Regexp.union(self.class.ignored_sql))
      @ignore = ignore
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if 'CACHE' == values[:name]

      self.class.all_log << sql
      self.class.log << sql unless ignore =~ sql
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end
