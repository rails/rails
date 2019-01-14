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
    with_service("mirror") do
      blob = directly_upload_file_blob
      assert_not ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)

      perform_enqueued_jobs do
        @user.highlights.attach(blob)
      end

      assert ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)
    end
  end
end
