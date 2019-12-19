# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "active_record/relation/record_fetch_warning"

module ActiveRecord
  class RecordFetchWarningTest < ActiveRecord::TestCase
    fixtures :posts

    def setup
      @original_logger = ActiveRecord::Base.logger
      @original_warn_on_records_fetched_greater_than = ActiveRecord::Base.warn_on_records_fetched_greater_than
      @log = StringIO.new
    end

    def teardown
      ActiveRecord::Base.logger = @original_logger
      ActiveRecord::Base.warn_on_records_fetched_greater_than = @original_warn_on_records_fetched_greater_than
    end

    def test_warn_on_records_fetched_greater_than_allowed_limit
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(@log)
      ActiveRecord::Base.logger.level = Logger::WARN
      ActiveRecord::Base.warn_on_records_fetched_greater_than = 1

      Post.all.to_a

      assert_match(/Query fetched/, @log.string)
    end

    def test_does_not_warn_on_records_fetched_less_than_allowed_limit
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(@log)
      ActiveRecord::Base.logger.level = Logger::WARN
      ActiveRecord::Base.warn_on_records_fetched_greater_than = 100

      Post.all.to_a

      assert_no_match(/Query fetched/, @log.string)
    end
  end
end
