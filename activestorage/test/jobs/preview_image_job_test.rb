# frozen_string_literal: true

require "test_helper"

require "active_storage/previewer/poppler_pdf_previewer"

class ActiveStorage::PreviewImageJobTest < ActiveJob::TestCase
  setup do
    @was_previewers = ActiveStorage.previewers

    @blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    @transformation = { resize_to_limit: [ 100, 100 ] }

    ActiveStorage.previewers = [ActiveStorage::Previewer::PopplerPDFPreviewer]
  end

  teardown do
    ActiveStorage.previewers = @previous_previewers
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
