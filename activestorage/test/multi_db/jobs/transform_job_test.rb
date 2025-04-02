# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::TransformJobTest < ActiveJob::TestCase
  setup do
    @main_blob = create_main_file_blob
    @animals_blob = create_animals_file_blob
  end

  test "creates main variant" do
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @main_blob.variant(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @main_blob, transformations
      end
    end
  end

  test "creates animals variant" do
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @animals_blob.variant(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @animals_blob, transformations
      end
    end
  end

  test "creates variant for main previewable file" do
    @main_blob = create_main_file_blob(filename: "report.pdf", content_type: "application/pdf")
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @main_blob.preview(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @main_blob, transformations
      end
      @main_blob.reload
    end

    assert @main_blob.preview(transformations).image.variant(transformations).send(:processed?)
  end

  test "creates variant for animals previewable file" do
    @animals_blob = create_animals_file_blob(filename: "report.pdf", content_type: "application/pdf")
    transformations = { resize_to_limit: [100, 100] }

    assert_changes -> { @animals_blob.preview(transformations).send(:processed?) }, from: false, to: true do
      perform_enqueued_jobs do
        ActiveStorage::TransformJob.perform_later @animals_blob, transformations
      end
      @animals_blob.reload
    end

    assert @animals_blob.preview(transformations).image.variant(transformations).send(:processed?)
  end

  test "creates main variant when untracked" do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
    transformations = { resize_to_limit: [100, 100] }

    begin
      assert_changes -> { @main_blob.variant(transformations).send(:processed?) }, from: false, to: true do
        perform_enqueued_jobs do
          ActiveStorage::TransformJob.perform_later @main_blob, transformations
        end
      end
    ensure
      ActiveStorage.track_variants = @was_tracking
    end
  end

  test "creates animals variant when untracked" do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
    transformations = { resize_to_limit: [100, 100] }

    begin
      assert_changes -> { @animals_blob.variant(transformations).send(:processed?) }, from: false, to: true do
        perform_enqueued_jobs do
          ActiveStorage::TransformJob.perform_later @animals_blob, transformations
        end
      end
    ensure
      ActiveStorage.track_variants = @was_tracking
    end
  end
  

  test "ignores unrepresentable main blob" do
    unrepresentable_main_blob = create_main_blob(content_type: "text/plain")
    transformations = { resize_to_limit: [100, 100] }

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::TransformJob.perform_later unrepresentable_main_blob, transformations
      end
    end
  end

  test "ignores unrepresentable animals blob" do
    unrepresentable_animals_blob = create_animals_blob(content_type: "text/plain")
    transformations = { resize_to_limit: [100, 100] }

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::TransformJob.perform_later unrepresentable_animals_blob, transformations
      end
    end
  end
end
