require "cases/helper"
require "models/binary"
require "models/developer"
require "models/post"
require "active_support/log_subscriber/test_helper"

class LogSubscriberTest < ActiveRecord::TestCase
  include ActiveSupport::LogSubscriber::TestHelper
  include ActiveSupport::Logger::Severity

  fixtures :posts

  def setup
    @old_logger = ActiveRecord::Base.logger
    Developer.primary_key
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
    event = Struct.new(:duration, :payload)

    logger = Class.new(ActiveRecord::LogSubscriber) {
      attr_accessor :debugs

      def initialize
        @debugs = []
        super
      end

      def debug message
        @debugs << message
      end
    }.new
    assert_equal 0, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!' }))
    assert_equal 1, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!', :name => 'foo' }))
    assert_equal 2, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!', :name => 'SCHEMA' }))
    assert_equal 2, logger.debugs.length
  end

  def test_basic_query_logging
    Developer.all.load
    wait
    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Developer Load/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
  end

  def test_exists_query_logging
    Developer.exists? 1
    wait
    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Developer Exists/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
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

  def test_binary_data_is_not_logged
    skip if current_adapter?(:Mysql2Adapter)

    Binary.create(:data => 'some binary data')
    wait
    assert_match(/<16 bytes of binary data>/, @logger.logged(:debug).join)
  end
end
