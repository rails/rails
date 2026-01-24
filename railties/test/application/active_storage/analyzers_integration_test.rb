# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveStorageEngineTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    include ActiveJob::TestHelper

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app

      rails "active_storage:install"

      rails "generate", "model", "user", "name:string", "avatar:attachment"
      rails "db:migrate"
    end

    def teardown
      teardown_app
    end

    def test_analyzers_default
      app("development")

      user = User.new(name: "Test User", avatar: file_fixture("racecar.jpg"))

      # Analysis happens synchronously from the local file during attachment
      assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
        user.save!
      end

      assert_predicate user.avatar, :analyzed?
    end

    def test_analyzers_empty
      add_to_config "config.active_storage.analyzers = []"

      app("development")

      user = User.new(name: "Test User", avatar: file_fixture("racecar.jpg"))

      assert_no_enqueued_jobs do
        user.save!
      end

      # Still marked as analyzed even with no analyzers (just no metadata extracted)
      assert_predicate user.avatar, :analyzed?
    end

    def test_analyze_job_enqueued_for_direct_upload
      app("development")

      # Simulate a direct upload by creating a blob first, then attaching it
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: "racecar.jpg",
        byte_size: file_fixture("racecar.jpg").size,
        checksum: OpenSSL::Digest::MD5.file(file_fixture("racecar.jpg")).base64digest,
        content_type: "image/jpeg"
      )
      blob.upload(file_fixture("racecar.jpg").open)

      user = User.new(name: "Test User")

      # For direct uploads (existing blobs), AnalyzeJob is still enqueued
      assert_enqueued_with(job: ActiveStorage::AnalyzeJob) do
        user.avatar.attach(blob)
        user.save!
      end
    end
  end
end
