# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::PreviewImageJobTest < ActiveJob::TestCase
  setup do
    @blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    @transformation = { resize_to_limit: [ 100, 100 ] }
  end

  test "creates preview" do
    assert_changes -> { @blob.preview_image.attached? }, from: false, to: true do
      ActiveStorage::PreviewImageJob.perform_now @blob, [ @transformation ]
    end
  end

  test "enqueues transform variant jobs" do
    assert_enqueued_with job: ActiveStorage::TransformJob, args: [ @blob, @transformation ] do
      ActiveStorage::PreviewImageJob.perform_now @blob, [ @transformation ]
    end
  end
end
