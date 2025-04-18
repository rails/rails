# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::FixtureSetTest < ActiveSupport::TestCase
  fixtures :all

  def test_active_storage_blob
    user = users(:first)

    avatar = user.avatar

    assert_equal "image/jpeg+override", avatar.blob.content_type
    assert_equal "racecar.jpg", avatar.blob.filename.to_s
    assert_equal :local, avatar.blob.service.name
    avatar.blob.open { |file| assert FileUtils.identical?(file, file_fixture("racecar.jpg")) }
  end

  def test_active_storage_attachment
    user = users(:first)

    avatar = user.avatar

    assert_not_predicate avatar, :blank?
    assert_predicate avatar, :attached?
    assert_predicate avatar.attachment, :present?
  end

  def test_active_storage_metadata
    user = users(:first)

    avatar = user.avatar.tap(&:analyze)

    assert avatar.metadata["identified"]
    assert avatar.metadata["analyzed"]
  end
end
