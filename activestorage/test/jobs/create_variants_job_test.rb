# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::CreateVariantsJobTest < ActiveJob::TestCase
  setup do
    @variants = [{ resize_to_limit: [ 100, 100 ] }, { resize_to_limit: [ 200, 200 ] }]
  end

  test "creates preview when previewable" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")

    assert_changes -> { blob.preview_image.attached? }, from: false, to: true do
      ActiveStorage::CreateVariantsJob.perform_now blob, variants: @variants, process: :later
    end
  end

  test "enqueues individual transform jobs for each transformation when process: :later" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, variants: @variants, process: :later

    @variants.each do |transformations|
      assert_enqueued_with job: ActiveStorage::TransformJob, args: [ blob, transformations ]
    end
  end

  test "does not transform when process: :later" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, variants: @variants, process: :later

    @variants.each do |transformations|
      assert_not blob.variant(transformations).processed?
    end
  end

  test "performs transformations immediately when process: :immediately" do
    blob = create_file_blob
    ActiveStorage::CreateVariantsJob.perform_now blob, variants: @variants, process: :immediately

    @variants.each do |transformations|
      assert blob.variant(transformations).processed?
    end
  end
end
