# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AnalyzeJobTest < ActiveJob::TestCase
  setup { @blob = create_blob }

  test "ignores missing blob" do
    @blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @blob
      end
    end
  end

  test "skips an analyzed blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    downloads = []
    callback = ->(event) { downloads << event.name }

    ActiveSupport::Notifications.subscribed(callback, /\Aservice_(streaming_)?download/) do
      ActiveStorage::AnalyzeJob.perform_now blob
      assert_not_empty downloads
      downloads.clear

      ActiveStorage::AnalyzeJob.perform_now blob
    end

    assert_empty downloads
  end
end
