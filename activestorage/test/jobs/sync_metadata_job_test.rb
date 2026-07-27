# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::SyncMetadataJobTest < ActiveJob::TestCase
  setup { @blob = create_blob }

  test "syncs metadata" do
    assert_notification("service_update_metadata.active_storage", key: @blob.key) do
      ActiveStorage::SyncMetadataJob.perform_now @blob
    end
  end

  test "ignores missing blob" do
    @blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::SyncMetadataJob.perform_later @blob
      end
    end
  end
end
