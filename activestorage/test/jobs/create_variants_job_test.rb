# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::CreateVariantsJobTest < ActiveJob::TestCase
  setup do
    @transformations = [{ resize_to_limit: [ 100, 100 ] }, { resize_to_limit: [ 200, 200 ] }]
  end

  test "creates preview when previewable" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")

    assert_changes -> { blob.preview_image.attached? }, from: false, to: true do
      ActiveStorage::CreateVariantsJob.perform_now blob, process: :later, transformations: @transformations
    end
  end

  test "enqueues individual transform jobs for each transformation when process: :later" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, process: :later, transformations: @transformations

    @transformations.each do |transformation|
      assert_enqueued_with job: ActiveStorage::TransformJob, args: [ blob, transformation ]
    end
  end

  test "does not transform when process: :later" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, process: :later, transformations: @transformations

    @transformations.each do |transformation|
      assert_not blob.variant(transformation).send(:processed?)
    end
  end

  test "performs transformations immediately when process: :immediately" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, process: :immediately, transformations: @transformations

    @transformations.each do |transformation|
      assert blob.variant(transformation).send(:processed?)
    end
  end
end
