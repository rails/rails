# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::AnalyzeJobTest < ActiveJob::TestCase
  setup do
    @main_blob = create_main_blob
    @animals_blob = create_animals_blob
  end

  test "ignores missing main blob" do
    @main_blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @main_blob
      end
    end
  end

  test "ignores missing animals blob" do
    @animals_blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @animals_blob
      end
    end
  end
end
