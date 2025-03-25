# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::PreviewImageJobTest < ActiveJob::TestCase
  setup do
    @main_blob = create_main_file_blob(filename: "report.pdf", content_type: "application/pdf")
    @animals_blob = create_animals_file_blob(filename: "report.pdf", content_type: "application/pdf")
    @transformation = { resize_to_limit: [ 100, 100 ] }
  end

  test "creates main preview" do
    assert_changes -> { @main_blob.preview_image.attached? }, from: false, to: true do
      ActiveStorage::PreviewImageJob.perform_now @main_blob, [ @transformation ]
    end
  end

  test "creates preview" do
    assert_changes -> { @animals_blob.preview_image.attached? }, from: false, to: true do
      ActiveStorage::PreviewImageJob.perform_now @animals_blob, [ @transformation ]
    end
  end

  test "enqueues main transform variant jobs" do
    assert_enqueued_with job: ActiveStorage::TransformJob, args: [ @main_blob, @transformation ] do
      ActiveStorage::PreviewImageJob.perform_now @main_blob, [ @transformation ]
    end
  end

  test "enqueues animals transform variant jobs" do
    assert_enqueued_with job: ActiveStorage::TransformJob, args: [ @animals_blob, @transformation ] do
      ActiveStorage::PreviewImageJob.perform_now @animals_blob, [ @transformation ]
    end
  end
end
