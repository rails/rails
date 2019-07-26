# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(name: "Josh")
  end

  teardown { ActiveStorage::Blob.all.each(&:delete) }

  test "analyzing a directly-uploaded blob after attaching it" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")
    assert_not blob.analyzed?

    perform_enqueued_jobs do
      @user.highlights.attach(blob)
    end

    assert blob.reload.analyzed?
    assert_equal 4104, blob.metadata[:width]
    assert_equal 2736, blob.metadata[:height]
  end

  test "mirroring a directly-uploaded blob after attaching it" do
    previous_service, ActiveStorage::Blob.service = ActiveStorage::Blob.service, build_mirror_service

    blob = directly_upload_file_blob
    assert_not ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)

    perform_enqueued_jobs do
      @user.highlights.attach(blob)
    end

    assert ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)
  ensure
    ActiveStorage::Blob.service = previous_service
  end

  private
    def build_mirror_service
      ActiveStorage::Service::MirrorService.new \
        primary: build_disk_service("primary"),
        mirrors: 3.times.collect { |i| build_disk_service("mirror_#{i + 1}") }
    end

    def build_disk_service(purpose)
      ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests_#{purpose}"))
    end
end
