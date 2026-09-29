# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::GenericLifecycleTransactionTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  setup do
    @owner_class.define_model_callbacks :rollback
  end

  test "nested and repeated saves upload only surviving blobs at the outer commit" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("original")
    owner.save!
    original = owner.icon.blob
    uploaded_keys = []
    track_uploads = ->(event) { uploaded_keys << event.payload.fetch(:key) }
    superseded = replacement = photos = nil

    ActiveSupport::Notifications.subscribed(track_uploads, "service_upload.active_storage") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.icon = lifecycle_upload("superseded")
        owner.save!
        superseded = owner.icon.blob
        owner.icon = lifecycle_upload("replacement")
        owner.save!
        replacement = owner.icon.blob
        owner.photos.attach(lifecycle_upload("first"))
        owner.photos.attach(lifecycle_upload("second"))
        ActiveStorage::InMemoryBackend.transaction do
          owner.save!
          owner.save!
        end
        photos = owner.photos.blobs.to_a

        assert_empty uploaded_keys
        assert original.persisted?
        assert superseded.persisted?
        assert original.service.exist?(original.key)
        [superseded, replacement, *photos].each { |blob| assert_not blob.service.exist?(blob.key) }
      end
    end

    assert_equal [replacement.key, *photos.map(&:key)].sort, uploaded_keys.sort
    assert_equal "replacement", owner.icon.download
    assert_equal ["first", "second"], owner.photos.blobs.map(&:download)
    [original, superseded].each do |blob|
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
    end
    assert_empty owner.attachment_changes
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end

  test "outer rollback restores rows and retains replacement assignments for retry" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("original icon")
    owner.favorites = [lifecycle_upload("original favorite")]
    owner.save!
    originals = [owner.icon.blob, *owner.favorites.blobs]
    owner.icon = lifecycle_upload("replacement icon")
    owner.favorites = [lifecycle_upload("replacement favorite")]
    changes = owner.attachment_changes.dup
    replacements = [owner.icon.blob, *owner.favorites.blobs]

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.save!
        raise "rollback"
      end
    end

    assert owner.persisted?
    stored = @owner_class.find(owner.id)
    assert_equal "original icon", stored.icon.download
    assert_equal ["original favorite"], stored.favorites.blobs.map(&:download)
    changes.each { |name, change| assert_same change, owner.attachment_changes[name] }
    replacements.each do |blob|
      assert_not blob.persisted?
      assert_not blob.service.exist?(blob.key)
    end

    ActiveStorage::InMemoryBackend.transaction { owner.save! }

    assert_equal "replacement icon", owner.icon.download
    assert_equal ["replacement favorite"], owner.favorites.blobs.map(&:download)
    originals.each { |blob| assert_not blob.persisted? }
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end

  test "destroy rollback restores owner persistence and rows before rollback callbacks" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("original")
    owner.save!
    original = owner.icon.blob
    owner.avatar = lifecycle_upload("pending")
    pending = owner.attachment_changes.fetch("avatar")
    rollback_states = []
    @owner_class.after_rollback do
      rollback_states << [persisted?, self.class.find(id).icon.attached?]
    end

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.destroy
        assert_not owner.persisted?
        assert_not owner.icon.attached?
        assert original.persisted?
        raise "rollback"
      end
    end

    assert_equal [[true, true]], rollback_states
    assert owner.persisted?
    assert_equal "original", owner.icon.download
    assert_same pending, owner.attachment_changes["avatar"]
    owner.save!
    assert_equal "pending", owner.avatar.download
    assert original.persisted?
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end

  test "new owner rollback retains assigned identities without reusing them" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("pending")
    pending = owner.attachment_changes.fetch("avatar")

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        owner.save!
        raise "rollback"
      end
    end

    assert_not owner.persisted?
    assert_not pending.blob.persisted?
    assert_not pending.attachment.persisted?
    assert_same pending, owner.attachment_changes["avatar"]
    other = @owner_class.new(name: "Other")
    other.avatar = lifecycle_upload("other")
    other.save!
    assert_operator other.id, :>, owner.id
    assert_operator other.avatar.blob.id, :>, pending.blob.id

    owner.save!
    assert_equal "pending", owner.avatar.download
    assert_equal "other", other.avatar.download
  end

  test "a later owner failure rolls back every participant and permits retry" do
    first = @owner_class.new(name: "First")
    first.avatar = lifecycle_upload("first avatar")
    first.photos = [lifecycle_upload("first photo")]
    second = @owner_class.new(name: "Second")
    second.avatar = lifecycle_upload("second avatar")
    second.photos = [lifecycle_upload("second photo")]
    fail_save = true
    @owner_class.after_save { raise "second owner failed" if name == "Second" && fail_save }
    rollback_owners = []
    @owner_class.after_rollback { rollback_owners << self }

    assert_raises(RuntimeError, "second owner failed") do
      ActiveStorage::InMemoryBackend.transaction do
        first.save!
        second.save!
      end
    end

    assert_equal [first.object_id, second.object_id], rollback_owners.map(&:object_id)
    assert_empty @owner_class.store
    assert_empty ActiveStorage.blob_class.records
    assert_empty ActiveStorage.attachment_class.records
    [first, second].each do |owner|
      assert_not owner.persisted?
      assert_equal ["avatar", "photos"], owner.attachment_changes.keys
    end

    fail_save = false
    ActiveStorage::InMemoryBackend.transaction do
      first.save!
      second.save!
    end

    assert_equal "first avatar", first.avatar.download
    assert_equal ["first photo"], first.photos.blobs.map(&:download)
    assert_equal "second avatar", second.avatar.download
    assert_equal ["second photo"], second.photos.blobs.map(&:download)
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end

  test "different instances of one record each receive transaction callbacks" do
    first = create_memory_blob
    second = ActiveStorage.blob_class.find(first.id)
    assert_equal first, second
    commits = []
    [first, second].each do |blob|
      blob.define_singleton_method(:run_callbacks) do |name, &block|
        commits << object_id if name == :commit
        super(name, &block)
      end
    end

    ActiveStorage::InMemoryBackend.transaction do
      first.save!
      second.save!
      assert_empty commits
    end

    assert_equal [first.object_id, second.object_id], commits
  end

  test "rollback restores independent snapshots across backend stores" do
    blob = create_memory_blob
    blob.metadata = { custom: { label: "original" } }
    blob.save!
    variant = ActiveStorage.variant_record_class.new(blob_id: blob.id, variation_digest: "original")
    variant.save!

    assert_raises(RuntimeError, "rollback") do
      ActiveStorage::InMemoryBackend.transaction do
        blob.metadata[:custom][:label] = "changed"
        blob.save!
        blob.metadata[:custom][:label] = "changed again"
        variant.variation_digest = "changed"
        variant.save!
        raise "rollback"
      end
    end

    assert_equal({ custom: { label: "original" } }, ActiveStorage.blob_class.find(blob.id).metadata)
    assert_equal "original", ActiveStorage.variant_record_class.find(variant.id).variation_digest
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end

  test "commit callbacks run outside the transaction and cannot roll back committed rows" do
    owner = @owner_class.new(name: "Dorian")
    other = @owner_class.new(name: "Other")
    @owner_class.after_commit do
      if name == "Dorian"
        raise "transaction still open" if ActiveStorage::InMemoryBackend::Transaction.current
        other.save!
        raise "commit failed"
      end
    end

    error = assert_raises(RuntimeError) do
      ActiveStorage::InMemoryBackend.transaction { owner.save! }
    end

    assert_equal "commit failed", error.message
    assert owner.persisted?
    assert other.persisted?
    assert_equal "Dorian", @owner_class.find(owner.id).name
    assert_equal "Other", @owner_class.find(other.id).name
    assert_nil ActiveStorage::InMemoryBackend::Transaction.current
  end
end
