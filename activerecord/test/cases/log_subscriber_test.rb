# frozen_string_literal: true

require "cases/helper"
require "models/binary"
require "models/developer"
require "models/post"
require "active_support/log_subscriber/test_helper"

class LogSubscriberTest < ActiveRecord::TestCase
  include ActiveSupport::LogSubscriber::TestHelper
  include ActiveSupport::Logger::Severity
  REGEXP_CLEAR = Regexp.escape(ActiveRecord::LogSubscriber::CLEAR)
  REGEXP_BOLD = Regexp.escape(ActiveRecord::LogSubscriber::BOLD)
  REGEXP_MAGENTA = Regexp.escape(ActiveRecord::LogSubscriber::MAGENTA)
  REGEXP_CYAN = Regexp.escape(ActiveRecord::LogSubscriber::CYAN)
  SQL_COLORINGS = {
      SELECT: Regexp.escape(ActiveRecord::LogSubscriber::BLUE),
      INSERT: Regexp.escape(ActiveRecord::LogSubscriber::GREEN),
      UPDATE: Regexp.escape(ActiveRecord::LogSubscriber::YELLOW),
      DELETE: Regexp.escape(ActiveRecord::LogSubscriber::RED),
      LOCK: Regexp.escape(ActiveRecord::LogSubscriber::WHITE),
      ROLLBACK: Regexp.escape(ActiveRecord::LogSubscriber::RED),
      TRANSACTION: REGEXP_CYAN,
      OTHER: REGEXP_MAGENTA
  }
  Event = Struct.new(:duration, :payload)

  class TestDebugLogSubscriber < ActiveRecord::LogSubscriber
    attr_reader :debugs

    def initialize
      @debugs = []
      super
    end

    def debug(progname = nil, &block)
      @debugs << progname
      super
    end
  end

  fixtures :posts

  def setup
    @old_logger = ActiveRecord::Base.logger
    Developer.primary_key
    ActiveRecord::Base.connection.materialize_transactions
    super
    ActiveRecord::LogSubscriber.attach_to(:active_record)
  end

  def teardown
    super
    ActiveRecord::LogSubscriber.log_subscribers.pop
    ActiveRecord::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActiveRecord::Base.logger = logger
  end

  def test_schema_statements_are_ignored
    logger = TestDebugLogSubscriber.new
    assert_equal 0, logger.debugs.length

    logger.sql(Event.new(0.9, sql: "hi mom!"))
    assert_equal 1, logger.debugs.length

    logger.sql(Event.new(0.9, sql: "hi mom!", name: "foo"))
    assert_equal 2, logger.debugs.length

    logger.sql(Event.new(0.9, sql: "hi mom!", name: "SCHEMA"))
    assert_equal 2, logger.debugs.length
  end

  def test_sql_statements_are_not_squeezed
    logger = TestDebugLogSubscriber.new
    logger.sql(Event.new(0.9, sql: "ruby   rails"))
    assert_match(/ruby   rails/, logger.debugs.first)
  end

  def test_basic_query_logging
    Developer.all.load
    wait
    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Developer Load/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
  end

  def test_basic_query_logging_coloration
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    SQL_COLORINGS.each do |verb, color_regex|
      logger.sql(Event.new(0.9, sql: verb.to_s))
      assert_match(/#{REGEXP_BOLD}#{color_regex}#{verb}#{REGEXP_CLEAR}/i, logger.debugs.last)
    end
  end

  def test_logging_sql_coloration_disabled
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = false

    SQL_COLORINGS.each do |verb, color_regex|
      logger.sql(Event.new(0.9, sql: verb.to_s))
      assert_no_match(/#{REGEXP_BOLD}#{color_regex}#{verb}#{REGEXP_CLEAR}/i, logger.debugs.last)
    end
  end

  def test_basic_payload_name_logging_coloration_generic_sql
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    SQL_COLORINGS.each do |verb, _|
      logger.sql(Event.new(0.9, sql: verb.to_s))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA} \(0\.9ms\)#{REGEXP_CLEAR}/i, logger.debugs.last)

      logger.sql(Event.new(0.9, sql: verb.to_s, name: "SQL"))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA}SQL \(0\.9ms\)#{REGEXP_CLEAR}/i, logger.debugs.last)
    end
  end

  def test_basic_payload_name_logging_coloration_named_sql
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    SQL_COLORINGS.each do |verb, _|
      logger.sql(Event.new(0.9, sql: verb.to_s, name: "Model Load"))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_CYAN}Model Load \(0\.9ms\)#{REGEXP_CLEAR}/i, logger.debugs.last)

      logger.sql(Event.new(0.9, sql: verb.to_s, name: "Model Exists"))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_CYAN}Model Exists \(0\.9ms\)#{REGEXP_CLEAR}/i, logger.debugs.last)

      logger.sql(Event.new(0.9, sql: verb.to_s, name: "ANY SPECIFIC NAME"))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_CYAN}ANY SPECIFIC NAME \(0\.9ms\)#{REGEXP_CLEAR}/i, logger.debugs.last)
    end
  end

  def test_query_logging_coloration_with_nested_select
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    SQL_COLORINGS.slice(:SELECT, :INSERT, :UPDATE, :DELETE).each do |verb, color_regex|
      logger.sql(Event.new(0.9, sql: "#{verb} WHERE ID IN SELECT"))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA} \(0\.9ms\)#{REGEXP_CLEAR}  #{REGEXP_BOLD}#{color_regex}#{verb} WHERE ID IN SELECT#{REGEXP_CLEAR}/i, logger.debugs.last)
    end
  end

  def test_query_logging_coloration_with_multi_line_nested_select
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    SQL_COLORINGS.slice(:SELECT, :INSERT, :UPDATE, :DELETE).each do |verb, color_regex|
      sql = <<-EOS
        #{verb}
        WHERE ID IN (
          SELECT ID FROM THINGS
        )
      EOS
      logger.sql(Event.new(0.9, sql: sql))
      assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA} \(0\.9ms\)#{REGEXP_CLEAR}  #{REGEXP_BOLD}#{color_regex}.*#{verb}.*#{REGEXP_CLEAR}/mi, logger.debugs.last)
    end
  end

  def test_query_logging_coloration_with_lock
    logger = TestDebugLogSubscriber.new
    logger.colorize_logging = true
    sql = <<-EOS
      SELECT * FROM
        (SELECT * FROM mytable FOR UPDATE) ss
      WHERE col1 = 5;
    EOS
    logger.sql(Event.new(0.9, sql: sql))
    assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA} \(0\.9ms\)#{REGEXP_CLEAR}  #{REGEXP_BOLD}#{SQL_COLORINGS[:LOCK]}.*FOR UPDATE.*#{REGEXP_CLEAR}/mi, logger.debugs.last)

    sql = <<-EOS
      LOCK TABLE films IN SHARE MODE;
    EOS
    logger.sql(Event.new(0.9, sql: sql))
    assert_match(/#{REGEXP_BOLD}#{REGEXP_MAGENTA} \(0\.9ms\)#{REGEXP_CLEAR}  #{REGEXP_BOLD}#{SQL_COLORINGS[:LOCK]}.*LOCK TABLE.*#{REGEXP_CLEAR}/mi, logger.debugs.last)
  end

  def test_exists_query_logging
    Developer.exists? 1
    wait
    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Developer Exists/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
  end

  def test_vebose_query_logs
    ActiveRecord::Base.verbose_query_logs = true

    logger = TestDebugLogSubscriber.new
    logger.sql(Event.new(0, sql: "hi mom!"))
    assert_equal 2, @logger.logged(:debug).size
    assert_match(/↳/, @logger.logged(:debug).last)
  ensure
    ActiveRecord::Base.verbose_query_logs = false
  end

  def test_verbose_query_with_ignored_callstack
    ActiveRecord::Base.verbose_query_logs = true

    logger = TestDebugLogSubscriber.new
    def logger.extract_query_source_location(*); nil; end

    logger.sql(Event.new(0, sql: "hi mom!"))
    assert_equal 1, @logger.logged(:debug).size
    assert_no_match(/↳/, @logger.logged(:debug).last)
  ensure
    ActiveRecord::Base.verbose_query_logs = false
  end

  def test_verbose_query_logs_disabled_by_default
    logger = TestDebugLogSubscriber.new
    logger.sql(Event.new(0, sql: "hi mom!"))
    assert_no_match(/↳/, @logger.logged(:debug).last)
  end

  def test_cached_queries
    ActiveRecord::Base.cache do
      Developer.all.load
      Developer.all.load
    end
    wait
    assert_equal 2, @logger.logged(:debug).size
    assert_match(/CACHE/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
  end

  def test_basic_query_doesnt_log_when_level_is_not_debug
    @logger.level = INFO
    Developer.all.load
    wait
    assert_equal 0, @logger.logged(:debug).size
  end

  def test_cached_queries_doesnt_log_when_level_is_not_debug
    @logger.level = INFO
    ActiveRecord::Base.cache do
      Developer.all.load
      Developer.all.load
    end
    wait
    assert_equal 0, @logger.logged(:debug).size
  end

  def test_initializes_runtime
    Thread.new { assert_equal 0, ActiveRecord::LogSubscriber.runtime }.join
  end

  if ActiveRecord::Base.connection.prepared_statements
    def test_where_in_binds_logging_include_attribute_names
      Developer.where(id: [1, 2, 3, 4, 5]).load
      wait
      assert_match(%{["id", 1], ["id", 2], ["id", 3], ["id", 4], ["id", 5]}, @logger.logged(:debug).last)
    end

    def test_binary_data_is_not_logged
      Binary.create(data: "some binary data")
      wait
      assert_match(/<16 bytes of binary data>/, @logger.logged(:debug).join)
    end

    def test_binary_data_hash
      Binary.create(data: { a: 1 })
      wait
      assert_match(/<7 bytes of binary data>/, @logger.logged(:debug).join)
    end
  end
end
