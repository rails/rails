require "cases/helper"
require "models/developer"
require "active_support/log_subscriber/test_helper"

class LogSubscriberTest < ActiveRecord::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    @old_logger = ActiveRecord::Base.logger
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

  def test_basic_query_logging
    Developer.all
    wait
    assert_equal 1, @logger.logged(:debug).size
    assert_match(/Developer Load/, @logger.logged(:debug).last)
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
end
