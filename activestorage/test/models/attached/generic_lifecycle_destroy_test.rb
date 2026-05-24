# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::GenericLifecycleDestroyTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  setup do
    @owner_class.define_model_callbacks :rollback
  end

  test "destroy rollback restores unsaved one and many assignments beside a newer unrelated assignment" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("pending avatar")
    owner.photos = [lifecycle_upload("pending photo")]
    pending = owner.attachment_changes.dup

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        assert_not owner.avatar.attached?
        assert_not owner.photos.attached?
        owner.icon = lifecycle_upload("new icon")
        raise "rollback"
      end
    end

    assert owner.persisted?
    pending.each { |name, change| assert_same change, owner.attachment_changes[name] }
    owner.save!

    assert_equal "pending avatar", owner.avatar.download
    assert_equal ["pending photo"], owner.photos.blobs.map(&:download)
    assert_equal "new icon", owner.icon.download
    assert_empty owner.attachment_changes
  end

  test "newer assignments and cancellations take precedence over changes suspended by destroy" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("superseded avatar")
    owner.photos = [lifecycle_upload("cancelled photo")]
    owner.cover_photo = lifecycle_upload("cancelled cover")
    superseded = [owner.avatar.blob, *owner.photos.blobs, owner.cover_photo.blob]
    current = nil

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        owner.avatar = lifecycle_upload("replacement")
        owner.photos = nil
        owner.cover_photo = lifecycle_upload("detached replacement")
        owner.cover_photo.detach
        current = owner.attachment_changes.dup
        raise "rollback"
      end
    end

    current.each { |name, change| assert_same change, owner.attachment_changes[name] }
    owner.save!

    assert_equal "replacement", owner.avatar.download
    assert_not owner.photos.attached?
    assert_not owner.cover_photo.attached?
    superseded.each do |blob|
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
    end
  end

  test "repeated destruction and resaving retain every current assignment on rollback" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("before destroy")
    pending_avatar = owner.attachment_changes.fetch("avatar")

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        owner.photos = [lifecycle_upload("between destroys")]
        owner.save!
        owner.destroy
        owner.icon = lifecycle_upload("after destroys")
        raise "rollback"
      end
    end

    assert_same pending_avatar, owner.attachment_changes["avatar"]
    owner.save!

    assert_equal "before destroy", owner.avatar.download
    assert_equal ["between destroys"], owner.photos.blobs.map(&:download)
    assert_equal "after destroys", owner.icon.download
  end

  test "successful reload discards assignments suspended by an earlier destroy" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("discarded")
    discarded = owner.avatar.blob

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        owner.save!
        owner.reload
        raise "rollback"
      end
    end

    assert_empty owner.attachment_changes
    owner.save!
    assert_not owner.avatar.attached?
    assert_not discarded.persisted?
    assert_not discarded.service.exist?(discarded.key)
  end

  test "duplicating a destroyed owner does not inherit its suspended assignment" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("original only")
    pending = owner.attachment_changes.fetch("avatar")
    copy = nil

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        copy = owner.dup
        copy.save!
        assert_not copy.avatar.attached?
        raise "rollback"
      end
    end

    assert_empty copy.attachment_changes
    copy.save!
    assert_not copy.avatar.attached?
    assert_not pending.blob.service.exist?(pending.blob.key)
    assert_same pending, owner.attachment_changes["avatar"]
    owner.save!
    assert_equal "original only", owner.avatar.download
  end

  test "destroying and resaving an owner purges its orphaned blobs after commit" do
    [:icon, :avatar].each do |name|
      owner = @owner_class.new(name: "Dorian")
      owner.public_send("#{name}=", lifecycle_upload("orphan"))
      owner.save!
      blob = owner.public_send(name).blob
      owner.cover_photo = lifecycle_upload("discarded pending")
      discarded = owner.cover_photo.blob

      perform_enqueued_jobs only: ActiveStorage::PurgeJob do
        ActiveStorage::InMemoryBackend.transaction do
          owner.destroy
          owner.save!
          assert blob.persisted?
          assert blob.service.exist?(blob.key)
        end
      end

      assert owner.persisted?
      assert_not owner.public_send(name).attached?
      assert_not blob.persisted?, "#{name} left an orphan after destroy and resave"
      assert_not blob.service.exist?(blob.key)
      assert_not discarded.persisted?
      assert_not discarded.service.exist?(discarded.key)
      assert_nil owner.send(:attachment_upload_source, discarded)
    end
  end

  test "destroy and resave preserve blobs reattached to the owner and shared with another owner" do
    [:icon, :avatar].each do |name|
      owner = @owner_class.new(name: "Dorian")
      owner.public_send("#{name}=", lifecycle_upload("shared"))
      owner.save!
      blob = owner.public_send(name).blob
      other = @owner_class.new(name: "Basil")

      perform_enqueued_jobs only: ActiveStorage::PurgeJob do
        ActiveStorage::InMemoryBackend.transaction do
          owner.destroy
          other.cover_photo = blob
          other.save!
          owner.public_send("#{name}=", blob)
          owner.save!
        end
      end

      assert blob.persisted?
      assert_equal "shared", owner.public_send(name).download
      assert_equal "shared", other.cover_photo.download
      assert_equal 2, ActiveStorage.attachment_class.where(blob_id: blob.id).to_a.size
    end
  end

  test "rollback after destroy and resave restores rows and files without purging" do
    [:icon, :avatar].each do |name|
      owner = @owner_class.new(name: "Dorian")
      owner.public_send("#{name}=", lifecycle_upload("restored"))
      owner.save!
      attachment = owner.public_send(name).attachment
      blob = attachment.blob

      assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
        assert_raises(RuntimeError, "rollback") do
          ActiveStorage::InMemoryBackend.transaction do
            owner.destroy
            owner.save!
            raise "rollback"
          end
        end
        owner.save!
      end

      assert owner.persisted?
      assert attachment.persisted?
      assert blob.persisted?
      assert_equal "restored", owner.public_send(name).download
      assert_equal attachment.id, owner.public_send(name).attachment.id
    end
  end

  test "destroying during an upload drains its purges and cancels the remaining uploads" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("first"), lifecycle_upload("cancelled")]
    first, cancelled = owner.photos.blobs
    upload = first.service.method(:upload)
    keys = []
    destroyed = false
    callback = lambda do |key, io, **options|
      keys << key
      upload.call(key, io, **options).tap do
        unless destroyed
          destroyed = true
          owner.destroy
        end
      end
    end

    perform_enqueued_jobs only: ActiveStorage::PurgeJob do
      first.service.stub(:upload, callback) do
        ActiveStorage::InMemoryBackend.transaction { owner.save! }
      end
    end

    assert_equal [first.key], keys
    assert_not owner.persisted?
    assert_empty owner.attachment_changes
    [first, cancelled].each do |blob|
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
    end
    assert_nil owner.send(:attachment_upload_source, cancelled)
    assert_empty ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id).to_a
  end
end
