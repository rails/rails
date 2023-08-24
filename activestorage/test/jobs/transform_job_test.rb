# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::TransformJobTest < ActiveJob::TestCase
  setup { @blob = create_file_blob }

  test "creates variant" do
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @blob.variant(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @blob, transformations
      end
    end
  end

  test "creates variant when untracked" do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
    transformations = { resize_to_limit: [100, 100] }

    begin
      assert_changes -> { @blob.variant(transformations).send(:processed?) }, from: false, to: true do
        perform_enqueued_jobs do
          ActiveStorage::TransformJob.perform_later @blob, transformations
        end
      end
    ensure
      ActiveStorage.track_variants = @was_tracking
    end
  end
end
