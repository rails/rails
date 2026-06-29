# frozen_string_literal: true

require "test_helper"

class ActiveStorage::LoadHooksTest < ActiveSupport::TestCase
  {
    active_storage_base_job: "ActiveStorage::BaseJob",
    active_storage_analyze_job: "ActiveStorage::AnalyzeJob",
    active_storage_create_variants_job: "ActiveStorage::CreateVariantsJob",
    active_storage_mirror_job: "ActiveStorage::MirrorJob",
    active_storage_preview_image_job: "ActiveStorage::PreviewImageJob",
    active_storage_purge_job: "ActiveStorage::PurgeJob",
    active_storage_sync_metadata_job: "ActiveStorage::SyncMetadataJob",
    active_storage_transform_job: "ActiveStorage::TransformJob"
  }.each do |hook, job_class_name|
    test "#{hook} load hook runs with #{job_class_name}" do
      job_class = nil
      ActiveSupport.on_load(hook) { job_class = self }

      assert_equal job_class_name.constantize, job_class
    end
  end
end
