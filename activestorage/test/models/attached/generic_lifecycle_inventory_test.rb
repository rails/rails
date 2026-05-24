# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::GenericLifecycleInventoryTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  setup do
    @owner_class.define_model_callbacks :rollback
    [:avatar, :photos, :icon].each do |name|
      @owner_class.attachment_reflections[name.to_s].options[:analyze] = :later
    end
  end

  test "replacing an unsaved IO assignment with its blob retains immediate analysis and upload" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar_with_immediate_analysis = lifecycle_upload("retained")
    blob = owner.avatar_with_immediate_analysis.blob
    owner.avatar_with_immediate_analysis = blob

    ActiveStorage::InMemoryBackend.transaction do
      assert owner.valid?
      assert blob.analyzed?
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
      owner.save!
    end

    assert_equal "retained", owner.avatar_with_immediate_analysis.download
    assert ActiveStorage.blob_class.find(blob.id).analyzed?
  end

  test "moving an unsaved IO blob to an immediate attachment analyzes before persistence" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("transferred")
    blob = owner.avatar.blob
    owner.avatar_with_immediate_analysis = blob
    owner.avatar = nil

    ActiveStorage::InMemoryBackend.transaction do
      assert owner.valid?
      assert blob.analyzed?
      assert_not blob.persisted?
      owner.save!
      assert_not blob.service.exist?(blob.key)
    end

    assert_not owner.avatar.attached?
    assert_equal "transferred", owner.avatar_with_immediate_analysis.download
    assert ActiveStorage.blob_class.find(blob.id).analyzed?
  end

  test "failed validation retains IO for reassignment and immediate analysis on retry" do
    owner = @owner_class.new
    owner.avatar = lifecycle_upload("validation retry")
    blob = owner.avatar.blob

    assert_not owner.save
    assert_not blob.persisted?
    assert_not blob.analyzed?
    owner.name = "Dorian"
    owner.avatar_with_immediate_analysis = blob
    owner.avatar = nil

    assert owner.valid?
    assert blob.analyzed?
    assert_not blob.service.exist?(blob.key)
    owner.save!

    assert_equal "validation retry", owner.avatar_with_immediate_analysis.download
  end

  test "cancelling and reloading unsaved assignments release their retained IO sources" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("cancelled")
    cancelled = owner.avatar.blob
    inventory = owner.instance_variable_get(:@active_storage_lifecycle)
    assert_not_nil inventory.upload_source_for(cancelled)

    owner.avatar = nil

    assert_nil inventory.upload_source_for(cancelled)
    owner.avatar = lifecycle_upload("reloaded")
    reloaded = owner.avatar.blob
    assert_not_nil inventory.upload_source_for(reloaded)

    owner.reload

    assert_nil inventory.upload_source_for(reloaded)
    assert_empty owner.attachment_changes
    [cancelled, reloaded].each do |blob|
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
    end
  end

  test "duplicating an owner does not inherit the original IO source" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("original")
    blob = owner.avatar.blob
    copy = owner.dup

    assert_empty copy.attachment_changes
    assert_nil copy.instance_variable_get(:@active_storage_lifecycle)
    copy.save!
    assert_not copy.avatar.attached?
    assert_not blob.persisted?
    assert_not blob.service.exist?(blob.key)

    owner.save!

    assert_equal "original", owner.avatar.download
  end

  test "rollback retains IO for retry after saved blobs are reassigned to one many or another name" do
    [[:avatar, :avatar], [:photos, :photos], [:avatar, :icon]].each do |source, target|
      owner = @owner_class.new(name: "Dorian")
      owner.public_send("#{source}=", source == :photos ? [lifecycle_upload("retry")] : lifecycle_upload("retry"))
      blob = source == :photos ? owner.photos.blobs.first : owner.avatar.blob

      assert_raises(RuntimeError, "rollback") do
        ActiveStorage::InMemoryBackend.transaction do
          owner.save!
          owner.public_send("#{target}=", target == :photos ? [blob] : blob)
          owner.public_send("#{source}=", nil) unless source == target
          owner.save!
          raise "rollback"
        end
      end

      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
      ActiveStorage::InMemoryBackend.transaction { owner.save! }

      attachment = owner.public_send(target)
      assert_equal "retry", target == :photos ? attachment.blobs.first.download : attachment.download
      assert ActiveStorage.blob_class.find(blob.id).analyzed?
      assert_empty owner.attachment_changes
    end
  end

  test "an older commit merges analysis into a pending blob without persisting its custom metadata" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("pending metadata").merge(metadata: { custom: { label: "original" } })
    original = owner.avatar.blob
    pending_blob = pending_change = nil

    ActiveStorage::InMemoryBackend.transaction do
      owner.save!
      owner.reload
      pending_blob = ActiveStorage.blob_class.find(original.id)
      pending_blob.metadata[:custom][:label] = "pending"
      owner.avatar = pending_blob
      pending_change = owner.attachment_changes.fetch("avatar")
      assert_equal "pending", owner.avatar.blob.custom_metadata[:label]
    end

    stored = ActiveStorage.blob_class.find(original.id)
    assert stored.analyzed?
    assert_equal "original", stored.custom_metadata[:label]
    assert_same pending_change, owner.attachment_changes["avatar"]
    assert pending_blob.analyzed?
    assert_equal "pending", pending_blob.custom_metadata[:label]

    owner.save!

    stored = ActiveStorage.blob_class.find(original.id)
    assert stored.analyzed?
    assert_equal "pending", stored.custom_metadata[:label]
    assert_equal "pending metadata", owner.avatar.download
  end

  test "upload uses the latest saved blob and updates its cached analysis metadata" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("latest metadata").merge(metadata: { custom: { label: "original" } })
    original = owner.avatar.blob
    latest = nil

    ActiveStorage::InMemoryBackend.transaction do
      owner.save!
      owner.reload
      latest = ActiveStorage.blob_class.find(original.id)
      latest.metadata[:custom][:label] = "latest"
      owner.avatar = latest
      owner.save!
    end

    assert owner.avatar.blob.analyzed?
    assert_equal "latest", owner.avatar.blob.custom_metadata[:label]
    assert latest.analyzed?
    assert_equal "latest", latest.custom_metadata[:label]
    stored = ActiveStorage.blob_class.find(original.id)
    assert stored.analyzed?
    assert_equal "latest", stored.custom_metadata[:label]
    assert_equal "latest metadata", owner.avatar.download
  end

  test "pending collection attachment readers retain their selected blob when the owner cache resets" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("pending photo").merge(metadata: { custom: { label: "original" } })]
    original = owner.photos.blobs.first
    pending_blob = pending_attachment = nil

    ActiveStorage::InMemoryBackend.transaction do
      owner.save!
      owner.reload
      pending_blob = ActiveStorage.blob_class.find(original.id)
      pending_blob.metadata[:custom][:label] = "pending"
      owner.photos = [pending_blob]
      pending_attachment = owner.photos.attachments.first
      assert_equal "pending", pending_attachment.blob.custom_metadata[:label]
      owner.photos_attachments.reset
      owner.photos_attachments.to_a
    end

    assert pending_attachment.blob.analyzed?
    assert_equal "pending", pending_attachment.blob.custom_metadata[:label]
    assert_equal "original", ActiveStorage.blob_class.find(original.id).custom_metadata[:label]
    owner.save!
    assert ActiveStorage.blob_class.find(original.id).analyzed?
    assert_equal "pending", ActiveStorage.blob_class.find(original.id).custom_metadata[:label]
  end

  test "normalized persisted metadata preserves pending nested edits deletions and nil values" do
    with_string_metadata_persistence do
      owner = @owner_class.new(name: "Dorian")
      custom = { label: "original", removed: "remove", cleared: "clear", unchanged: "kept" }
      owner.avatar = lifecycle_upload("normalized").merge(metadata: { custom: custom.deep_dup })
      pending_blob = owner.avatar.blob

      ActiveStorage::InMemoryBackend.transaction do
        owner.save!
        owner.reload
        pending_blob.metadata[:custom][:label] = "pending"
        pending_blob.metadata[:custom].delete(:removed)
        pending_blob.metadata[:custom][:cleared] = nil
        owner.avatar = pending_blob
      end

      stored = ActiveStorage.blob_class.find(pending_blob.id)
      assert stored.analyzed?
      assert_equal custom.deep_stringify_keys, stored.custom_metadata
      assert pending_blob.analyzed?

      owner.save!

      stored = ActiveStorage.blob_class.find(pending_blob.id)
      assert stored.analyzed?
      assert_equal({ "label" => "pending", "cleared" => nil, "unchanged" => "kept" }, stored.custom_metadata)
      assert_equal "normalized", owner.avatar.download
    end
  end

  test "saving a new assignment during upload commits each generation once" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("first")]
    first = owner.photos.blobs.first
    service = first.service
    upload = service.method(:upload)
    keys = []
    second = nil
    reentered = false
    callback = lambda do |key, io, **options|
      keys << key
      upload.call(key, io, **options).tap do
        unless reentered
          reentered = true
          owner.photos = owner.photos.blobs + [lifecycle_upload("second")]
          second = owner.photos.blobs.last
          owner.save!
        end
      end
    end

    service.stub(:upload, callback) do
      ActiveStorage::InMemoryBackend.transaction { owner.save! }
    end

    assert_equal [first.key, second.key], keys
    assert_equal ["first", "second"], owner.photos.blobs.map(&:download)
    assert ActiveStorage.blob_class.find(second.id).analyzed?
    assert_empty owner.attachment_changes
  end

  test "assigning during upload leaves the new IO pending until its own save" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("first")
    first = owner.avatar.blob
    service = first.service
    upload = service.method(:upload)
    pending = nil
    keys = []
    callback = lambda do |key, io, **options|
      keys << key
      upload.call(key, io, **options).tap do
        owner.avatar = lifecycle_upload("pending")
        pending = owner.attachment_changes.fetch("avatar")
      end
    end

    service.stub(:upload, callback) do
      ActiveStorage::InMemoryBackend.transaction { owner.save! }
    end

    assert_equal [first.key], keys
    assert_same pending, owner.attachment_changes["avatar"]
    assert_not pending.blob.persisted?
    assert_not pending.blob.service.exist?(pending.blob.key)
    assert_equal "first", @owner_class.find(owner.id).avatar.download

    owner.save!

    assert_equal "pending", owner.avatar.download
    assert_empty owner.attachment_changes
  end

  test "removing a later photo during upload prevents its upload in the current commit" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("first"), lifecycle_upload("removed")]
    first, removed = owner.photos.blobs
    upload = first.service.method(:upload)
    keys = []
    reentered = false
    callback = lambda do |key, io, **options|
      keys << key
      upload.call(key, io, **options).tap do
        unless reentered
          reentered = true
          owner.photos = [first]
          owner.save!
        end
      end
    end

    first.service.stub(:upload, callback) do
      ActiveStorage::InMemoryBackend.transaction { owner.save! }
    end

    assert_equal [first.key], keys
    assert_not removed.service.exist?(removed.key)
    assert_equal ["first"], owner.photos.blobs.map(&:download)
    assert_empty owner.attachment_changes
  end

  private
    def with_string_metadata_persistence
      blob_class = ActiveStorage.blob_class
      persistence = blob_class.instance_method(:attributes_for_persistence)
      silence_warnings do
        blob_class.define_method(:attributes_for_persistence) do
          attributes = persistence.bind_call(self)
          attributes.merge(metadata: attributes.fetch(:metadata).deep_stringify_keys)
        end
      end
      blob_class.send(:private, :attributes_for_persistence)
      yield
    ensure
      silence_warnings { blob_class.define_method(:attributes_for_persistence, persistence) }
      blob_class.send(:private, :attributes_for_persistence)
    end
end
