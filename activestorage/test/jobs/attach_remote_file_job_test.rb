# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "webmock/minitest"

class ActiveStorage::AttachRemoteFileJobTest < ActiveJob::TestCase
  setup do
    @user = User.create! name: "Test"
  end

  test "#perform downloads and attaches a file" do
    url = "https://example.com/racecar.jpg"
    stub_request(:get, url).to_return(body: file_fixture("racecar.jpg"))

    assert_changes -> { @user.reload.avatar.attached? }, from: false, to: true do
      ActiveStorage::AttachRemoteFileJob.perform_now(@user, :avatar, url)
    end
  end

  test "#perform discards the job on a 404" do
    url = "https://example.com/racecar.jpg"
    stub_request(:get, url).to_return(status: 404)

    assert_no_changes -> { @user.reload.avatar.attached? }, from: false do
      ActiveStorage::AttachRemoteFileJob.perform_now(@user, :avatar, url)
    end
  end

  test "#perform discards the job when the attachment column does not exist" do
    url = "http://junk"

    perform_enqueued_jobs do
      assert_raises NoMethodError do
        ActiveStorage::AttachRemoteFileJob.perform_later(@user, :junk, url)
      end
    end

    assert_no_enqueued_jobs
  end

  test "#perform discards the job when the record does not exist" do
    url = "https://example.com/racecar.jpg"

    perform_enqueued_jobs do
      ActiveStorage::AttachRemoteFileJob.perform_later(@user.tap(&:destroy!), :avatar, url)
    end

    assert_no_enqueued_jobs
  end
end
