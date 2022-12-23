# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ManyAttachedCallbacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.new name: "test"
  end

  test "#highlights_urls= will enqueue an ActiveStorage::AttachRemoteFileJob on save" do
    url = "http://example.com/racecar.jpg"

    assert_enqueued_with job: ActiveStorage::AttachRemoteFileJob, args: [@user, :highlights, url] do
      @user.update! highlights_urls: [url]
    end
  end

  test "sets the attribute to nil after save" do
    @user.highlights_urls = ["http://example.com/racecar.jpg"]

    assert_changes -> { @user.highlights_urls }, to: nil do
      @user.save
    end
  end

  test "#highlights_urls= won't enqueue an ActiveStorage::AttachRemoteFileJob when the value is nil" do
    assert_no_enqueued_jobs do
      @user.update! highlights_urls: nil
    end
  end

  test "#highlights_urls= won't enqueue an ActiveStorage::AttachRemoteFileJob when the value is blank" do
    assert_no_enqueued_jobs do
      @user.update! highlights_urls: [""]
    end
  end

  test "#highlights_urls= won't enqueue an ActiveStorage::AttachRemoteFileJob on a failed save" do
    url = "http://example.com/racecar.jpg"

    assert_no_enqueued_jobs do
      @user.update name: nil, highlights_urls: [url]
    end
  end
end
