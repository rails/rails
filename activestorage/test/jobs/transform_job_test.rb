# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::TransformJobTest < ActiveJob::TestCase
  setup { @blob = create_file_blob }

  test "creates variant" do
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @blob.variant(transformations).processed? }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @blob, transformations
      end
    end
  end
end
