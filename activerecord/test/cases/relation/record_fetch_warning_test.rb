require 'cases/helper'
require 'models/post'

module ActiveRecord
  class RecordFetchWarningTest < ActiveRecord::TestCase
    fixtures :posts

    def test_warn_on_records_fetched_greater_than
      original_logger = ActiveRecord::Base.logger
      original_warn_on_records_fetched_greater_than = ActiveRecord::Base.warn_on_records_fetched_greater_than

      log = StringIO.new
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
      ActiveRecord::Base.logger.level = Logger::WARN

      require 'active_record/relation/record_fetch_warning'

      ActiveRecord::Base.warn_on_records_fetched_greater_than = 1

      Post.all.to_a

      assert_match(/Query fetched/, log.string)
    ensure
      ActiveRecord::Base.logger = original_logger
      ActiveRecord::Base.warn_on_records_fetched_greater_than = original_warn_on_records_fetched_greater_than
    end
  end
end
