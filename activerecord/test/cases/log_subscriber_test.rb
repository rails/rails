require "cases/helper"
require "models/developer"
require "models/post"
require "active_support/log_subscriber/test_helper"

class LogSubscriberTest < ActiveRecord::TestCase
  include ActiveSupport::LogSubscriber::TestHelper
  include ActiveSupport::BufferedLogger::Severity

  class TestDebugLogSubscriber < ActiveRecord::LogSubscriber
    attr_reader :debugs

    def initialize
      @debugs = []
      super
    end

    def debug message
      @debugs << message
    end
  end

  fixtures :posts

  def setup
    @old_logger = ActiveRecord::Base.logger
    @using_identity_map = ActiveRecord::IdentityMap.enabled?
    ActiveRecord::IdentityMap.enabled = false
    Developer.primary_key
    super
    ActiveRecord::LogSubscriber.attach_to(:active_record)
  end

  def teardown
    super
    ActiveRecord::LogSubscriber.log_subscribers.pop
    ActiveRecord::Base.logger = @old_logger
    ActiveRecord::IdentityMap.enabled = @using_identity_map
  end

  def set_logger(logger)
    ActiveRecord::Base.logger = logger
  end

  def test_schema_statements_are_ignored
    event = Struct.new(:duration, :payload)

    logger = TestDebugLogSubscriber.new
    assert_equal 0, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!' }))
    assert_equal 1, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!', :name => 'foo' }))
    assert_equal 2, logger.debugs.length

    logger.sql(event.new(0, { :sql => 'hi mom!', :name => 'SCHEMA' }))
    assert_equal 2, logger.debugs.length
  end

  def test_ignore_binds_payload_with_nil_column
    event = Struct.new(:duration, :payload)

    logger = TestDebugLogSubscriber.new
    logger.sql(event.new(0, :sql => 'hi mom!', :binds => [[nil, 1]]))
    assert_equal 1, logger.debugs.length
  end

  def test_basic_query_logging
    Developer.all
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
      Developer.all
      Developer.all
    end
    wait
    assert_equal 2, @logger.logged(:debug).size
    assert_match(/CACHE/, @logger.logged(:debug).last)
    assert_match(/SELECT .*?FROM .?developers.?/i, @logger.logged(:debug).last)
  end

  def test_basic_query_doesnt_log_when_level_is_not_debug
    @logger.level = INFO
    Developer.all
    wait
    assert_equal 0, @logger.logged(:debug).size
  end

  def test_cached_queries_doesnt_log_when_level_is_not_debug
    @logger.level = INFO
    ActiveRecord::Base.cache do
      Developer.all
      Developer.all
    end
    wait
    assert_equal 0, @logger.logged(:debug).size
  end

  def test_initializes_runtime
    Thread.new { assert_equal 0, ActiveRecord::LogSubscriber.runtime }.join
  end

  def test_log
    ActiveRecord::IdentityMap.use do
      Post.find 1
      Post.find 1
    end
    wait
    assert_match(/From Identity Map/, @logger.logged(:debug).last)
  end
end
