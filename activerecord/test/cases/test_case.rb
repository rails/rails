require 'active_support/test_case'
require 'active_support/testing/stream'

module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    include ActiveSupport::Testing::Stream

    def teardown
      SQLCounter.clear_log
    end

    def capture_sql
      SQLCounter.clear_log
      yield
      SQLCounter.log_all.dup
    end

    def assert_sql(*patterns_to_match)
      capture_sql { yield }
    ensure
      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless SQLCounter.log_all.any?{ |sql| pattern === sql }
      end
      assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:inspect).join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.join("\n")}"}"
    end

    def assert_queries(num = 1, options = {})
      ignore_none = options.fetch(:ignore_none) { num == :any }
      SQLCounter.clear_log
      x = yield
      the_log = ignore_none ? SQLCounter.log_all : SQLCounter.log
      if num == :any
        assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
      else
        mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
        assert_equal num, the_log.size, mesg
      end
      x
    end

    def assert_no_queries(options = {}, &block)
      options.reverse_merge! ignore_none: true
      assert_queries(0, options, &block)
    end

    def assert_column(model, column_name, msg=nil)
      assert has_column?(model, column_name), msg
    end

    def assert_no_column(model, column_name, msg=nil)
      assert_not has_column?(model, column_name), msg
    end

    def has_column?(model, column_name)
      model.reset_column_information
      model.column_names.include?(column_name.to_s)
    end
  end

  class PostgreSQLTestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:PostgreSQLAdapter)
    end
  end

  class Mysql2TestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:Mysql2Adapter)
    end
  end

  class SQLite3TestCase < TestCase
    def self.run(*args)
      super if current_adapter?(:SQLite3Adapter)
    end
  end

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    self.clear_log

    self.ignored_sql = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/, /^BEGIN/, /^COMMIT/]

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL, or better yet, use a different notification for the queries
    # instead examining the SQL content.
    oracle_ignored     = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im, /^\s*select .* from all_constraints/im, /^\s*select .* from all_tab_cols/im]
    mysql_ignored      = [/^SHOW FULL TABLES/i, /^SHOW FULL FIELDS/, /^SHOW CREATE TABLE /i, /^SHOW VARIABLES /, /^\s*SELECT (?:column_name|table_name)\b.*\bFROM information_schema\.(?:key_column_usage|tables)\b/im]
    postgresql_ignored = [/^\s*select\b.*\bfrom\b.*pg_namespace\b/im, /^\s*select tablename\b.*from pg_tables\b/im, /^\s*select\b.*\battname\b.*\bfrom\b.*\bpg_attribute\b/im, /^SHOW search_path/i]
    sqlite3_ignored =    [/^\s*SELECT name\b.*\bFROM sqlite_master/im, /^\s*SELECT sql\b.*\bFROM sqlite_master/im]

    [oracle_ignored, mysql_ignored, postgresql_ignored, sqlite3_ignored].each do |db_ignored_sql|
      ignored_sql.concat db_ignored_sql
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

      self.class.log_all << sql
      self.class.log << sql unless ignore =~ sql
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end
