# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::OneAttachedCallbacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.new name: "test"
  end

  test "#avatar_url= will enqueue an ActiveStorage::AttachRemoteFileJob on save" do
    url = "http://example.com/racecar.jpg"

    assert_enqueued_with job: ActiveStorage::AttachRemoteFileJob, args: [@user, :avatar, url] do
      @user.update! avatar_url: url
    end
  end

  test "sets the attribute to nil after save" do
    @user.avatar_url = "http://example.com/racecar.jpg"

    assert_changes -> { @user.avatar_url }, to: nil do
      @user.save
    end
  end

  test "#avatar_url= won't enqueue an ActiveStorage::AttachRemoteFileJob when the value is nil" do
    assert_no_enqueued_jobs do
      @user.update! avatar_url: nil
    end
  end

  test "#avatar_url= won't enqueue an ActiveStorage::AttachRemoteFileJob when the value is blank" do
    assert_no_enqueued_jobs do
      @user.update! avatar_url: ""
    end
  end

  test "#avatar_url= won't enqueue an ActiveStorage::AttachRemoteFileJob on a failed save" do
    url = "http://example.com/racecar.jpg"

    assert_no_enqueued_jobs do
      @user.update name: nil, avatar_url: url
    end
  end
end
