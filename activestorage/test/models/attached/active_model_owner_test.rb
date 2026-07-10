# frozen_string_literal: true

require "test_helper"
require_relative "../../fixtures/active_storage/in_memory_backend"
require_relative "../../fixtures/active_model_owner"

class ActiveStorage::ActiveModelOwnerAttachedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @raw_blob_class = ActiveStorage.class_variable_get(:@@blob_class)
    @raw_attachment_class = ActiveStorage.class_variable_get(:@@attachment_class)
    @raw_variant_record_class = ActiveStorage.class_variable_get(:@@variant_record_class)
    @services_registry = ActiveStorage::Services.registry
    @services_default = ActiveStorage::Services.default
    @track_variants = ActiveStorage.track_variants
    ActiveStorage.track_variants = false

    ActiveStorage.class_variable_set(:@@blob_class, "ActiveStorage::InMemoryBackend::Blob")
    ActiveStorage.class_variable_set(:@@attachment_class, "ActiveStorage::InMemoryBackend::Attachment")
    ActiveStorage.class_variable_set(:@@variant_record_class, "ActiveStorage::InMemoryBackend::VariantRecord")
    ActiveStorage.clear_class_indirection_cache
    ActiveStorage::Services.registry = ActiveStorage::Service::Registry.new(Rails.configuration.active_storage.service_configurations)
    ActiveStorage::Services.default = ActiveStorage::Services.registry.fetch(Rails.configuration.active_storage.service)
    ActiveStorage::InMemoryBackend.install
    ActiveStorage::InMemoryBackend.reset
    @owner_class = ActiveStorage::ActiveModelOwnerFixture.define!
  end

  teardown do
    ActiveStorage.track_variants = @track_variants
    ActiveStorage::InMemoryBackend.reset
    %i[
      ActiveModelOwner
      PlainActiveModelOwner
      NoCommitOwner
      NoCommitPurgeOwner
      NoCommitClearIdOwner
      NoCommitSharedBlobOwner
      NoCommitSharedBlobSubOwner
      NoCommitCollideOwner
      MinimalDependentOwner
      StaleDestroyFailureOwner
      HaltedDestroyOwner
      RollbackDestroyOwner
      PrependCaptureOwner
      PendingServiceOwner
      EmptyRegistryOwner
    ].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
    if ActiveStorage::InMemoryBackend.const_defined?(:AttachmentWithoutDependentPurge, false)
      ActiveStorage::InMemoryBackend.send(:remove_const, :AttachmentWithoutDependentPurge)
    end
    if ActiveStorage::InMemoryBackend.const_defined?(:AttachmentWithHaltedDestroy, false)
      ActiveStorage::InMemoryBackend.send(:remove_const, :AttachmentWithHaltedDestroy)
    end
    if ActiveStorage::InMemoryBackend.const_defined?(:AttachmentWithStaleDestroyFailure, false)
      ActiveStorage::InMemoryBackend.send(:remove_const, :AttachmentWithStaleDestroyFailure)
    end
    ActiveStorage.class_variable_set(:@@blob_class, @raw_blob_class)
    ActiveStorage.class_variable_set(:@@attachment_class, @raw_attachment_class)
    ActiveStorage.class_variable_set(:@@variant_record_class, @raw_variant_record_class)
    ActiveStorage.clear_class_indirection_cache
    ActiveStorage::Services.registry = @services_registry
    ActiveStorage::Services.default = @services_default
    ActiveStorage::Attached::Model.pending_service_validations.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "declares active model reflections and accessors" do
    owner = @owner_class.new(name: "Dorian")

    assert_instance_of ActiveStorage::Attached::One, owner.avatar
    assert_instance_of ActiveStorage::Attached::Many, owner.photos
    assert_equal :has_one_attached, @owner_class.reflect_on_attachment(:avatar).macro
    assert_equal :has_many_attached, @owner_class.reflect_on_attachment(:photos).macro
  end

  test "refuses owners that do not satisfy the callback contract" do
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      def self.find(id)
      end
    end

    error = assert_raises(ActiveStorage::OwnerContractMissing) do
      owner_class.has_one_attached :avatar
    end
    assert_match "validation callbacks", error.message
  end

  test "refuses owners that do not define an id" do
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      def self.find(id)
      end

      def persisted?
        true
      end
    end

    error = assert_raises(ActiveStorage::OwnerContractMissing) do
      owner_class.has_one_attached :avatar
    end
    assert_match "#id", error.message
  end

  test "refuses owners that rely on the default ActiveModel persisted?" do
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      attr_accessor :id

      def self.find(id)
      end
    end

    error = assert_raises(ActiveStorage::OwnerContractMissing) do
      owner_class.has_one_attached :avatar
    end
    assert_match "persisted?", error.message
  end

  test "refuses active model owners with default active record storage classes" do
    ActiveStorage.class_variable_set(:@@blob_class, "ActiveStorage::Blob")
    ActiveStorage.class_variable_set(:@@attachment_class, "ActiveStorage::Attachment")
    ActiveStorage.class_variable_set(:@@variant_record_class, "ActiveStorage::VariantRecord")
    ActiveStorage.clear_class_indirection_cache

    error = assert_raises(ActiveStorage::HybridConfigurationError) do
      ActiveStorage::ActiveModelOwnerFixture.define!(name: "PlainActiveModelOwner")
    end
    assert_match "default ActiveRecord storage classes", error.message
  end

  test "queues named service validation until services registry is loaded" do
    ActiveStorage::Services.registry = nil
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      attr_accessor :id

      def self.find(id)
      end

      def persisted?
        id.present?
      end
    end
    Object.const_set(:PendingServiceOwner, owner_class)

    owner_class.has_one_attached :avatar, service: :local

    assert_includes ActiveStorage::Attached::Model.pending_service_validations,
      [ owner_class, :avatar, :local ]
  end

  test "empty services registry does not defer named service validation" do
    ActiveStorage::Services.registry = {}
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      attr_accessor :id

      def self.find(id)
      end

      def persisted?
        id.present?
      end
    end
    Object.const_set(:EmptyRegistryOwner, owner_class)

    error = assert_raises(ArgumentError) do
      owner_class.has_one_attached :avatar, service: :local
    end
    assert_match "Cannot configure service :local", error.message
  end

  test "raises on active model eager loading scopes" do
    assert_raises(ActiveStorage::EagerLoadingNotSupported) do
      @owner_class.with_attached_avatar
    end
  end

  test "refuses strict loading for active model owners" do
    error = assert_raises(ArgumentError) do
      @owner_class.has_one_attached :strict_avatar, strict_loading: true
    end

    assert_match "strict_loading: true", error.message
  end

  test "does not query attachments for unsaved active model owners without ids" do
    owner = @owner_class.new(name: "Dorian")

    ActiveStorage.attachment_class.stub(:find_by, ->(**) { raise "unexpected query" }) do
      assert_nil owner.avatar_attachment
    end
  end

  test "does not query has many attachments for unsaved active model owners without ids" do
    owner = @owner_class.new(name: "Dorian")

    ActiveStorage.attachment_class.stub(:where, ->(*) { raise "unexpected query" }) do
      assert_empty owner.photos
      assert_empty owner.photos_attachments
    end
  end

  test "does not query attachments for unsaved owners that carry a preassigned id" do
    owner = @owner_class.new(name: "Dorian")
    owner.id = 999
    # Mirror a backend (e.g. an aws-record model) where the primary key is
    # assigned before the record is saved: id is present but persisted? is false.
    owner.define_singleton_method(:persisted?) { false }

    ActiveStorage.attachment_class.stub(:find_by, ->(**) { raise "unexpected query" }) do
      assert_nil owner.avatar_attachment
    end

    ActiveStorage.attachment_class.stub(:where, ->(*) { raise "unexpected query" }) do
      assert_empty owner.photos
      assert_empty owner.photos_attachments
      assert_equal [], owner.photos_attachments.delete_all
    end
  end

  test "aborted owner destroy keeps generic attachment rows and does not purge" do
    # A before_destroy declared after the attachment halts the destroy chain
    # *after* Active Storage's destroy callbacks are registered. The attachment
    # rows and blob must survive together with the owner -- destroying them in
    # :destroy, :before would delete rows the aborted owner still references.
    @owner_class.set_callback(:destroy, :before) { throw :abort }

    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.avatar.attach(blob)

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      owner.destroy
    end

    assert owner.persisted?, "owner should survive an aborted destroy"
    assert blob.persisted?, "blob must survive an aborted owner destroy"
    assert_equal 1, ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: owner.id, name: "avatar").to_a.size,
      "attachment row must not be deleted when the owner destroy is aborted"
  end

  test "dup clears generic attachment memoizations" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar.attach(create_memory_blob(filename: "avatar.txt"))
    owner.photos.attach(create_memory_blob(filename: "photo.txt"))

    owner.avatar_attachment
    owner.avatar_blob
    owner.photos_attachments
    owner.photos_blobs

    duplicate = owner.dup

    assert_not duplicate.instance_variable_defined?(:@active_storage_attached)
    assert_not duplicate.instance_variable_defined?(:@attachment_changes)
    assert_not duplicate.instance_variable_defined?(:@avatar_attachment)
    assert_not duplicate.instance_variable_defined?(:@avatar_blob)
    assert_not duplicate.instance_variable_defined?(:@photos_attachments)
    assert_not duplicate.instance_variable_defined?(:@photos_blobs)
  end

  test "reload clears generic attachment memoizations" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "avatar.txt")
    owner.avatar.attach(blob)
    attachment = owner.avatar_attachment

    assert_equal blob, owner.avatar_blob

    attachment.delete
    owner.reload

    assert_nil owner.avatar_attachment
    assert_nil owner.avatar_blob
  end

  test "attaches and uploads after saving an unpersisted owner" do
    owner = @owner_class.new(name: "Dorian")

    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    assert owner.avatar.attached?
    assert_not owner.avatar.attachment.persisted?
    assert_not ActiveStorage.blob_class.service.exist?(owner.avatar.blob.key)

    assert owner.save

    assert owner.avatar.attachment.persisted?
    assert_equal "STUFF", owner.avatar.download
    assert ActiveStorage.blob_class.service.exist?(owner.avatar.blob.key)
  end

  test "cleans up newly persisted blobs when generic attachment save fails" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    change = ActiveStorage::Attached::Changes::CreateOne.new("avatar", owner, io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    change.attachment.define_singleton_method(:save!) do
      raise ActiveStorage::RecordNotSaved.new("Failed to save attachment", self)
    end

    assert_raises(ActiveStorage::RecordNotSaved) { change.save }
    assert_not change.blob.persisted?
    assert_empty ActiveStorage.blob_class.records
  end

  test "cleans up newly persisted blob records when blob delete would fail" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    change = ActiveStorage::Attached::Changes::CreateOne.new("avatar", owner, io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    change.blob.define_singleton_method(:delete) do
      raise "delete should not run before upload"
    end

    change.attachment.define_singleton_method(:save!) do
      raise ActiveStorage::RecordNotSaved.new("Failed to save attachment", self)
    end

    assert_raises(ActiveStorage::RecordNotSaved) { change.save }
    assert_not change.blob.persisted?
    assert_empty ActiveStorage.blob_class.records
  end

  test "cleans up has many blobs and attachments when a later generic attachment save fails" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    change = ActiveStorage::Attached::Changes::CreateMany.new("photos", owner, [
      { io: StringIO.new("FIRST"), filename: "first.txt", content_type: "text/plain" },
      { io: StringIO.new("SECOND"), filename: "second.txt", content_type: "text/plain" }
    ])

    change.attachments.second.define_singleton_method(:save!) do
      raise ActiveStorage::RecordNotSaved.new("Failed to save attachment", self)
    end

    assert_raises(ActiveStorage::RecordNotSaved) { change.save }
    assert_empty ActiveStorage.blob_class.records
    assert_empty ActiveStorage.attachment_class.records
    assert_empty change.deferred_purges
  end

  test "attaches immediately on persisted clean owners" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!

    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    assert owner.avatar.attachment.persisted?
    assert_equal "STUFF", owner.avatar.download
  end

  test "defers persisted dirty owner attachments until save" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.name = "Tina"

    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    assert owner.avatar.attached?
    assert_not owner.avatar.attachment.persisted?
    assert_not ActiveStorage.blob_class.service.exist?(owner.avatar.blob.key)

    owner.save!

    assert owner.avatar.attachment.persisted?
    assert_equal "STUFF", owner.avatar.download
  end

  test "treats owners without changed predicate as clean" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "PlainActiveModelOwner", dirty: false)
    owner = owner_class.new(name: "Dorian")
    owner.save!

    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    assert owner.avatar.attachment.persisted?
    assert_equal "STUFF", owner.avatar.download
  end

  test "attach bang raises active storage record not saved" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.name = nil
    owner.clear_changes_information

    assert_raises(ActiveStorage::RecordNotSaved) do
      owner.avatar.attach!(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")
    end
  end

  test "attaches an existing blob by signed id" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg", data: "SIGNED")

    owner.avatar.attach(blob.signed_id)

    assert_equal blob, owner.avatar.blob
    assert_equal "SIGNED", owner.avatar.download
  end

  test "replaces has one attachments" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.cover_photo.attach(old_blob)
    old_attachment = owner.cover_photo.attachment
    owner.cover_photo.attach(new_blob)

    assert_not old_attachment.persisted?
    assert old_blob.persisted?
    assert_equal new_blob, owner.cover_photo.blob
    assert_equal [ new_blob.id ], ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: "cover_photo").map(&:blob_id)
  end

  test "replacing has one attachments applies dependent purge" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.icon.attach(old_blob)
    owner.icon.attach(new_blob)

    assert_not old_blob.persisted?
    assert new_blob.persisted?
    assert_equal new_blob, owner.icon.blob
  end

  test "failed generic replacement does not purge stale dependent blob" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.icon.attach(old_blob)
    old_attachment = owner.icon.attachment
    change = ActiveStorage::Attached::Changes::CreateOne.new("icon", owner, new_blob)
    change.attachment.define_singleton_method(:save!) do
      raise ActiveStorage::RecordNotSaved.new("Failed to save attachment", self)
    end

    assert_raises(ActiveStorage::RecordNotSaved) { change.save }
    change.flush_deferred_purges

    assert old_blob.persisted?
    attachments = ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: "icon").to_a
    assert_equal [ old_attachment ], attachments
    assert_equal [ old_blob.id ], attachments.map(&:blob_id)
  end

  test "replacing default has one attachments enqueues dependent purge later" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.avatar.attach(old_blob)

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      owner.avatar.attach(new_blob)
    end
    assert old_blob.persisted?
    assert new_blob.persisted?
    assert_equal new_blob, owner.avatar.blob
  end

  test "clearing has one attachments applies dependent purge" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    owner.icon = nil
    owner.save!

    assert_not owner.icon.attached?
    assert_not blob.persisted?
  end

  test "detach removes attachment and keeps blob" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")
    blob = owner.avatar.blob

    owner.avatar.detach

    assert_not owner.avatar.attached?
    assert blob.persisted?
    assert ActiveStorage.blob_class.service.exist?(blob.key)
  end

  test "purge removes attachment blob and file" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")
    blob = owner.avatar.blob

    owner.avatar.purge

    assert_not owner.avatar.attached?
    assert_not blob.persisted?
    assert_not ActiveStorage.blob_class.service.exist?(blob.key)
  end

  test "purging one shared attachment keeps the blob until all attachments are gone" do
    owner = @owner_class.new(name: "Dorian")
    other_owner = @owner_class.new(name: "Basil")
    owner.save!
    other_owner.save!
    blob = create_memory_blob(filename: "shared.txt", data: "SHARED")

    owner.avatar.attach(blob)
    other_owner.avatar.attach(blob)

    owner.avatar.purge

    assert_not owner.avatar.attached?
    assert other_owner.avatar.attached?
    assert blob.persisted?
    assert ActiveStorage.blob_class.service.exist?(blob.key)

    other_owner.avatar.purge

    assert_not blob.persisted?
    assert_not ActiveStorage.blob_class.service.exist?(blob.key)
  end

  test "purge later enqueues purge job" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar.attach(create_memory_blob(filename: "funky.jpg"))

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      owner.avatar.purge_later
    end
  end

  test "has many attaches appends and exposes collection helpers" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    first_blob = create_memory_blob(filename: "funky.jpg", data: "FIRST")
    second_blob = create_memory_blob(filename: "town.jpg", data: "SECOND")

    owner.photos.attach(first_blob)
    owner.photos.attach(second_blob)

    assert_equal [ "funky.jpg", "town.jpg" ], owner.photos.map { |attachment| attachment.filename.to_s }
    assert_equal [ first_blob.id, second_blob.id ], owner.photos_blobs.pluck(:id)
    assert owner.photos_attachments.any? { |attachment| attachment.blob_id == first_blob.id }
    assert_equal first_blob.id, owner.photos_attachments.find_by(blob_id: first_blob.id).blob_id
    assert_same owner.photos_attachments, owner.photos_attachments.includes(:blob)
    assert_same owner.photos_attachments, owner.photos_attachments.with_all_variant_records
    assert_raises(ActiveStorage::QueryNotSupported) { owner.photos_attachments.where(blob_id: first_blob.id) }
    assert_raises(ActiveStorage::QueryNotSupported) { owner.photos_blobs.order(:created_at) }
  end

  test "has many attachments use id as secondary order for matching timestamps" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    first_blob = create_memory_blob(filename: "first.txt", data: "FIRST")
    second_blob = create_memory_blob(filename: "second.txt", data: "SECOND")

    owner.photos.attach(second_blob)
    owner.photos.attach(first_blob)

    matching_timestamp = Time.current
    ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: "photos").each do |attachment|
      attachment.created_at = matching_timestamp
      attachment.save!
    end

    expected_ids = ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: owner.id, name: "photos")
      .to_a
      .sort_by(&:id)
      .map(&:id)

    assert_equal expected_ids, owner.photos_attachments.reload.map(&:id)
  end

  test "has many assignment replaces stale attachments" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg")
    new_blob = create_memory_blob(filename: "new.jpg")

    owner.documents.attach(old_blob)
    old_attachment = owner.documents.first
    owner.documents = [ new_blob ]
    owner.save!

    assert_not old_attachment.persisted?
    assert old_blob.persisted?
    assert_equal [ new_blob.id ], owner.documents_blobs.pluck(:id)
  end

  test "has many assignment applies dependent purge to stale attachments" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg")
    kept_blob = create_memory_blob(filename: "kept.jpg")

    owner.favorites.attach(old_blob, kept_blob)
    owner.favorites = [ kept_blob ]
    owner.save!

    assert_not old_blob.persisted?
    assert kept_blob.persisted?
    assert_equal [ kept_blob.id ], owner.favorites_blobs.pluck(:id)
  end

  test "clearing has many attachments applies dependent purge" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    first_blob = create_memory_blob(filename: "funky.jpg")
    second_blob = create_memory_blob(filename: "town.jpg")

    owner.favorites.attach(first_blob, second_blob)
    owner.favorites = []
    owner.save!

    assert_empty owner.favorites
    assert_not first_blob.persisted?
    assert_not second_blob.persisted?
  end

  test "has many detach and purge reset collection caches" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    first_blob = create_memory_blob(filename: "funky.jpg")
    second_blob = create_memory_blob(filename: "town.jpg")

    owner.photos.attach(first_blob, second_blob)
    owner.photos.detach

    assert_empty owner.photos
    assert first_blob.persisted?
    assert second_blob.persisted?

    owner.favorites.attach(first_blob, second_blob)
    owner.favorites.purge

    assert_empty owner.favorites
    assert_not first_blob.persisted?
    assert_not second_blob.persisted?
  end

  test "dependent purge runs on owner destroy" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    owner.destroy

    assert_not blob.persisted?
  end

  test "owner without commit callbacks purges dependent blob after destroy" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitPurgeOwner", commit_callbacks: false)
    owner = owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    owner.destroy

    assert_not blob.persisted?
  end

  test "rolled back owner destroy clears deferred purge state" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "RollbackDestroyOwner", rollback_callbacks: true)
    owner_class.send(:remove_method, :destroy)
    owner_class.define_method(:destroy) do
      owner_snapshot = self.class.store[id]
      attachments = ActiveStorage.attachment_class.store.dup

      # Actually remove the owner so the after_destroy callbacks queue the
      # dependent purge, then simulate a transaction rollback that restores the
      # owner and its attachments before the :rollback callbacks fire.
      run_callbacks(:destroy) { self.class.store.delete(id) }
      self.class.store[id] = owner_snapshot
      ActiveStorage.attachment_class.store = Concurrent::Map.new.tap do |store|
        attachments.each { |attachment_id, attachment| store[attachment_id] = attachment }
      end
      run_callbacks(:rollback) { true }
      false
    end

    owner = owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "avatar.txt")
    owner.avatar.attach(blob)

    assert_not owner.destroy

    # The :rollback, :after callback cancels the deferred purge immediately,
    # before any later save/commit, so the state is already clear here.
    assert_nil owner.instance_variable_get(:@active_storage_destroy_deferred_purges)

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      owner.save!
    end
    assert blob.persisted?
  end

  test "owner destroy that completes without aborting and without deleting keeps attachment rows" do
    # A destroy that runs the callback chain to completion but does not remove
    # the owner (returns false instead of throw :abort) must not delete the
    # owner's attachment rows or purge its dependent blobs.
    @owner_class.send(:remove_method, :destroy)
    @owner_class.define_method(:destroy) do
      run_callbacks(:destroy) { false } # backend delete is a no-op; owner survives
      run_callbacks(:commit) { true }
      false
    end

    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      assert_not owner.destroy
    end

    assert owner.persisted?, "owner survives a destroy that does not delete it"
    assert blob.persisted?, "dependent blob must not be purged when the owner survives"
    assert_equal 1, ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: owner.id, name: "icon").to_a.size,
      "attachment rows must survive a destroy that leaves the owner persisted"
  end

  test "commit owner defers dependent blob purge until after commit" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob) # dependent: :purge

    # Run only the destroy phase: the attachment row is removed and the purge is
    # queued, but the blob is not purged until the commit phase fires.
    owner.send(:run_callbacks, :destroy) { owner.class.store.delete(owner.id) }

    assert_not owner.persisted?
    assert blob.persisted?, "dependent blob must survive until the commit phase"
    assert_empty ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: owner.id, name: "icon").to_a

    owner.send(:run_callbacks, :commit) { true }

    assert_not blob.persisted?, "dependent blob is purged after the commit phase"
  end

  test "commit owner without rollback callbacks discards a stale destroy purge on the next save" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.avatar.attach(blob) # default dependent: :purge_later

    owner_snapshot = owner.class.store[owner.id]
    attachments = ActiveStorage.attachment_class.store.dup

    # Simulate a backend transaction that ran the destroy callbacks (queuing the
    # purge) but rolled back without firing :commit: the owner and its
    # attachments are restored, leaving a stale deferred purge behind.
    owner.send(:run_callbacks, :destroy) { owner.class.store.delete(owner.id) }
    owner.class.store[owner.id] = owner_snapshot
    ActiveStorage.attachment_class.store = Concurrent::Map.new.tap do |store|
      attachments.each { |attachment_id, attachment| store[attachment_id] = attachment }
    end

    # The owner is persisted again, so the next commit must cancel the stale
    # purge instead of flushing it.
    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      owner.save!
    end
    assert blob.persisted?
  end

  test "commit owner does not flush a stale destroy purge on a later standalone commit" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.avatar.attach(blob) # default dependent: :purge_later

    owner_snapshot = owner.class.store[owner.id]
    attachments = ActiveStorage.attachment_class.store.dup

    # Destroy queues the purge; a rollback then restores the owner and its rows.
    owner.send(:run_callbacks, :destroy) { owner.class.store.delete(owner.id) }
    owner.class.store[owner.id] = owner_snapshot
    ActiveStorage.attachment_class.store = Concurrent::Map.new.tap do |store|
      attachments.each { |attachment_id, attachment| store[attachment_id] = attachment }
    end

    # A later commit not preceded by a save/destroy (e.g. a backend that commits
    # a transaction directly) must still cancel the stale purge, because the
    # owner is persisted again.
    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      owner.send(:run_callbacks, :commit) { true }
    end
    assert blob.persisted?
  end

  test "owner destroy purges dependent has many blobs and clears their rows" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    first_blob = create_memory_blob(filename: "first.jpg")
    second_blob = create_memory_blob(filename: "second.jpg")
    owner.favorites.attach(first_blob, second_blob) # has_many, dependent: :purge

    owner.destroy

    assert_not first_blob.persisted?
    assert_not second_blob.persisted?
    assert_empty ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: owner.id, name: "favorites").to_a
  end

  test "owner that clears its id while destroying still cleans up generic attachments" do
    # Some backends nil out the primary key as part of #destroy. Cleanup must
    # still target the right rows, so the record id is captured before destroy.
    @owner_class.send(:remove_method, :destroy)
    @owner_class.define_method(:destroy) do
      run_callbacks(:destroy) do
        self.class.store.delete(id)
        self.id = nil
      end
      run_callbacks(:commit) { true }
      true
    end

    owner = @owner_class.new(name: "Dorian")
    owner.save!
    record_id = owner.id
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob) # dependent: :purge

    owner.destroy

    assert_nil owner.id
    assert_not blob.persisted?, "dependent blob purged even though the owner cleared its id"
    assert_empty ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: record_id, name: "icon").to_a
  end

  test "owner without commit callbacks that clears its id while destroying still cleans up attachments" do
    # The no-commit destroy branch reads the same captured record id, so cleanup
    # must survive an owner that nils its id during a callback-less destroy.
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitClearIdOwner", commit_callbacks: false)
    owner_class.send(:remove_method, :destroy)
    owner_class.define_method(:destroy) do
      run_callbacks(:destroy) do
        self.class.store.delete(id)
        self.id = nil
      end
      true
    end

    owner = owner_class.new(name: "Dorian")
    owner.save!
    record_id = owner.id
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob) # dependent: :purge

    owner.destroy

    assert_nil owner.id
    assert_not blob.persisted?
    assert_empty ActiveStorage.attachment_class
      .where(record_type: owner.class.name, record_id: record_id, name: "icon").to_a
  end

  test "captures the owner id before a user before_destroy callback can clear it" do
    store = Concurrent::Map.new
    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveModel::Attributes
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy, :commit
      attribute :id, :integer

      # Declared BEFORE has_one_attached: without a prepended id capture this
      # runs first and blanks the id Active Storage needs for cleanup.
      before_destroy { self.id = nil }

      class << self
        attr_accessor :backing_store

        def find(id)
          backing_store.fetch(id.to_i) { raise ActiveStorage::RecordNotFound }
        end
      end

      def persisted?
        id.present? && self.class.backing_store.key?(id)
      end

      def save
        self.id ||= self.class.backing_store.size + 1
        run_callbacks(:save) { self.class.backing_store[id] = self }
        run_callbacks(:commit) { true }
        true
      end

      def destroy
        deleted_id = id
        run_callbacks(:destroy) { self.class.backing_store.delete(deleted_id) }
        run_callbacks(:commit) { true }
        true
      end
    end
    owner_class.backing_store = store
    Object.const_set(:PrependCaptureOwner, owner_class)
    owner_class.has_one_attached :icon, dependent: :purge

    owner = owner_class.new
    assert owner.save
    record_id = owner.id
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    owner.destroy

    assert_nil owner.id
    assert_not blob.persisted?, "id captured before the user callback cleared it"
    assert_empty ActiveStorage.attachment_class
      .where(record_type: "PrependCaptureOwner", record_id: record_id, name: "icon").to_a
  end

  test "owner without commit callbacks purges a blob shared across attachments once all rows are gone" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitSharedBlobOwner", commit_callbacks: false)
    # Declare a dependent: false attachment BEFORE a dependent: :purge one so the
    # :purge cleanup runs first (after_destroy callbacks fire in reverse). The
    # shared blob must still be purged once both rows are destroyed, not skipped
    # because the other row briefly still referenced it.
    owner_class.has_one_attached :shared_keep, dependent: false
    owner_class.has_one_attached :shared_purge, dependent: :purge

    owner = owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "shared.txt")
    owner.shared_keep.attach(blob)
    owner.shared_purge.attach(blob)

    owner.destroy

    assert_not blob.persisted?, "shared blob purged once all referencing rows are destroyed"
    assert_empty ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id).to_a
  end

  test "owner without commit callbacks enqueues a single purge for a blob shared across attachments" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitSharedBlobOwner", commit_callbacks: false)
    owner_class.has_one_attached :first_ref  # default dependent: :purge_later
    owner_class.has_one_attached :second_ref # default dependent: :purge_later

    owner = owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "shared.txt")
    owner.first_ref.attach(blob)
    owner.second_ref.attach(blob)

    # The blob is referenced twice but must be purged exactly once.
    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob do
      owner.destroy
    end
  end

  test "commit owner enqueues a single purge for a blob shared across attachments" do
    @owner_class.has_one_attached :first_ref  # default dependent: :purge_later
    @owner_class.has_one_attached :second_ref # default dependent: :purge_later

    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "shared.txt")
    owner.first_ref.attach(blob)
    owner.second_ref.attach(blob)

    # A commit owner must coalesce per-name purges the same way: the shared blob
    # is purged exactly once on destroy, not once per attachment name.
    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob do
      owner.destroy
    end
  end

  test "owner destroy purges a shared blob synchronously when any name is dependent purge" do
    # Declared so the :purge_later name is collected first (after callbacks fire
    # in reverse); the synchronous :purge must still win for the shared blob.
    @owner_class.has_one_attached :shared_purge_now, dependent: :purge
    @owner_class.has_one_attached :shared_purge_later, dependent: :purge_later

    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "shared.txt")
    owner.shared_purge_now.attach(blob)
    owner.shared_purge_later.attach(blob)

    # :purge beats :purge_later: the blob is purged synchronously, no job queued.
    assert_enqueued_jobs 0, only: ActiveStorage::PurgeJob do
      owner.destroy
    end
    assert_not blob.persisted?
  end

  test "no-commit owner subclass purges a blob shared with an inherited attachment after all rows are gone" do
    base_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitSharedBlobOwner", commit_callbacks: false)
    base_class.has_one_attached :inherited_keep, dependent: false

    sub_class = Class.new(base_class)
    Object.const_set(:NoCommitSharedBlobSubOwner, sub_class)
    sub_class.reset
    # The subclass inherits the single flush callback rather than registering its
    # own, so the inherited flush still runs last (after every collector,
    # including inherited ones) and the shared blob is purged once all rows go.
    sub_class.has_one_attached :sub_purge, dependent: :purge

    owner = sub_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "shared.txt")
    owner.inherited_keep.attach(blob)
    owner.sub_purge.attach(blob)

    owner.destroy

    assert_not blob.persisted?, "shared blob purged after all rows (including inherited) are destroyed"
  ensure
    Object.send(:remove_const, :NoCommitSharedBlobSubOwner) if Object.const_defined?(:NoCommitSharedBlobSubOwner, false)
  end

  test "destroying an unsaved owner with a colliding preassigned id leaves another record's attachments intact" do
    victim = @owner_class.new(name: "Victim")
    victim.save!
    blob = create_memory_blob(filename: "victim.jpg")
    victim.icon.attach(blob) # dependent: :purge

    attacker = @owner_class.new(name: "Attacker")
    attacker.id = victim.id # reuse a stored id without ever saving this record
    attacker.define_singleton_method(:persisted?) { false }
    attacker.define_singleton_method(:destroy) do
      # Never-saved owner: it has nothing of its own to remove.
      run_callbacks(:destroy) { }
      run_callbacks(:commit) { true }
      true
    end

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      attacker.destroy
    end

    assert blob.persisted?, "destroying an unsaved colliding owner must not purge another record's blob"
    assert_equal 1, ActiveStorage.attachment_class
      .where(record_type: @owner_class.name, record_id: victim.id, name: "icon").to_a.size,
      "another record's attachment rows must survive"
  end

  test "owner without commit callbacks destroying an unsaved colliding owner leaves another record's attachments intact" do
    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitCollideOwner", commit_callbacks: false)

    victim = owner_class.new(name: "Victim")
    victim.save!
    blob = create_memory_blob(filename: "victim.jpg")
    victim.icon.attach(blob) # dependent: :purge

    attacker = owner_class.new(name: "Attacker")
    attacker.id = victim.id
    attacker.define_singleton_method(:persisted?) { false }
    attacker.define_singleton_method(:destroy) do
      run_callbacks(:destroy) { }
      true
    end

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      attacker.destroy
    end

    assert blob.persisted?, "no-commit: destroying an unsaved colliding owner must not purge another record's blob"
    assert_equal 1, ActiveStorage.attachment_class
      .where(record_type: owner_class.name, record_id: victim.id, name: "icon").to_a.size,
      "no-commit: another record's attachment rows must survive"
  end

  test "generic destroy callback applies dependent purge without an attachment hook" do
    # This guards the generic path contract: dependent purging belongs to
    # Active Storage's destroy helper, not to backend attachment implementations.
    minimal_attachment_class = Class.new(ActiveStorage::InMemoryBackend::Attachment) do
      self.store = Concurrent::Map.new
      self.id_sequence = Concurrent::AtomicFixnum.new(0)

      def destroy
        @previously_persisted = persisted?
        run_callbacks(:destroy) { self.class.store.delete(id) }
        run_callbacks(:commit) { true }
        true
      end
    end

    ActiveStorage::InMemoryBackend.const_set(
      :AttachmentWithoutDependentPurge,
      minimal_attachment_class
    )
    ActiveStorage.class_variable_set(
      :@@attachment_class,
      "ActiveStorage::InMemoryBackend::AttachmentWithoutDependentPurge"
    )
    ActiveStorage.clear_class_indirection_cache

    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "MinimalDependentOwner")
    owner = owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")
    owner.icon.attach(blob)

    owner.destroy

    assert_not blob.persisted?
  end

  test "failed stale generic attachment destroy cleans up newly saved has one records" do
    stale_destroy_failure_attachment_class = Class.new(ActiveStorage::InMemoryBackend::Attachment) do
      self.store = Concurrent::Map.new
      self.id_sequence = Concurrent::AtomicFixnum.new(0)

      class << self
        attr_accessor :failed_destroy_blob_id
      end

      def destroy
        raise StandardError, "stale destroy failed" if blob_id == self.class.failed_destroy_blob_id

        super
      end
    end

    ActiveStorage::InMemoryBackend.const_set(
      :AttachmentWithStaleDestroyFailure,
      stale_destroy_failure_attachment_class
    )
    ActiveStorage.class_variable_set(
      :@@attachment_class,
      "ActiveStorage::InMemoryBackend::AttachmentWithStaleDestroyFailure"
    )
    ActiveStorage.clear_class_indirection_cache

    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "StaleDestroyFailureOwner")
    owner = owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")

    owner.cover_photo.attach(old_blob)
    old_attachment = owner.cover_photo.attachment
    ActiveStorage.attachment_class.failed_destroy_blob_id = old_blob.id

    error = assert_raises(StandardError) do
      owner.cover_photo.attach(io: StringIO.new("NEW"), filename: "new.jpg", content_type: "image/jpeg")
    end
    assert_equal "stale destroy failed", error.message

    failed_change = owner.attachment_changes.fetch("cover_photo")
    assert_not failed_change.attachment.persisted?
    assert_not failed_change.blob.persisted?

    attachments = ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: "cover_photo").to_a
    assert_equal [ old_attachment ], attachments
    assert_equal [ old_blob.id ], attachments.map(&:blob_id)
    assert_equal [ old_blob.id ], ActiveStorage.blob_class.records.map(&:id)
  end

  test "failed stale generic attachment destroy cleans up newly saved has many records" do
    stale_destroy_failure_attachment_class = Class.new(ActiveStorage::InMemoryBackend::Attachment) do
      self.store = Concurrent::Map.new
      self.id_sequence = Concurrent::AtomicFixnum.new(0)

      class << self
        attr_accessor :failed_destroy_blob_id
      end

      def destroy
        raise StandardError, "stale destroy failed" if blob_id == self.class.failed_destroy_blob_id

        super
      end
    end

    ActiveStorage::InMemoryBackend.const_set(
      :AttachmentWithStaleDestroyFailure,
      stale_destroy_failure_attachment_class
    )
    ActiveStorage.class_variable_set(
      :@@attachment_class,
      "ActiveStorage::InMemoryBackend::AttachmentWithStaleDestroyFailure"
    )
    ActiveStorage.clear_class_indirection_cache

    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "StaleDestroyFailureOwner")
    owner = owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.favorites.attach(old_blob)
    ActiveStorage.attachment_class.failed_destroy_blob_id = old_blob.id

    error = assert_raises(StandardError) do
      owner.favorites = [ new_blob ]
      owner.save!
    end
    assert_equal "stale destroy failed", error.message

    attachments = ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: "favorites").to_a
    assert_equal [ old_blob.id ], attachments.map(&:blob_id)
    assert new_blob.persisted?
  end

  test "halted generic attachment destroy raises instead of silently continuing" do
    halted_destroy_attachment_class = Class.new(ActiveStorage::InMemoryBackend::Attachment) do
      self.store = Concurrent::Map.new
      self.id_sequence = Concurrent::AtomicFixnum.new(0)

      def destroy
        false
      end
    end

    ActiveStorage::InMemoryBackend.const_set(
      :AttachmentWithHaltedDestroy,
      halted_destroy_attachment_class
    )
    ActiveStorage.class_variable_set(
      :@@attachment_class,
      "ActiveStorage::InMemoryBackend::AttachmentWithHaltedDestroy"
    )
    ActiveStorage.clear_class_indirection_cache

    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "HaltedDestroyOwner")
    owner = owner_class.new(name: "Dorian")
    owner.save!
    old_blob = create_memory_blob(filename: "old.jpg", data: "OLD")
    new_blob = create_memory_blob(filename: "new.jpg", data: "NEW")

    owner.cover_photo.attach(old_blob)

    assert_raises(ActiveStorage::RecordNotDestroyed) do
      owner.cover_photo.attach(new_blob)
    end
  end

  test "service proc receives active model owner" do
    owner = @owner_class.new(name: "Dorian", region: "mirror_2")
    owner.save!

    owner.regional_avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")

    assert_equal :disk_mirror_2, owner.regional_avatar.blob.service.name
  end

  test "owner without commit callbacks uploads after save and logs a warning" do
    log = StringIO.new
    previous_logger = ActiveStorage.logger
    ActiveStorage.logger = ActiveSupport::Logger.new(log)

    owner_class = ActiveStorage::ActiveModelOwnerFixture.define!(name: "NoCommitOwner", commit_callbacks: false)
    owner = owner_class.new(name: "Dorian")
    owner.avatar.attach(io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg")
    owner.save!

    assert_match "does not define :commit callbacks", log.string
    assert_equal "STUFF", owner.avatar.download
  ensure
    ActiveStorage.logger = previous_logger
  end

  test "generic owner analysis modes" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "funky.jpg")

    assert_not blob.analyzed?
    assert_enqueued_with(job: ActiveStorage::AnalyzeJob) do
      owner.avatar.attach(blob)
    end

    perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob)

    assert blob.analyzed?

    later_blob = create_memory_blob(filename: "later.txt")

    assert_not later_blob.analyzed?
    assert_enqueued_with(job: ActiveStorage::AnalyzeJob) do
      owner.avatar_with_later_analysis.attach(later_blob)
    end

    perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob)

    assert later_blob.analyzed?

    lazy_blob = create_memory_blob(filename: "lazy.txt")

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      owner.avatar_with_lazy_analysis.attach(lazy_blob)
    end

    assert_not lazy_blob.analyzed?

    immediate_owner = @owner_class.new(name: "Basil")

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      immediate_owner.avatar_with_immediate_analysis.attach(
        io: StringIO.new("STUFF"),
        filename: "town.jpg",
        content_type: "image/jpeg"
      )
      immediate_owner.save!
    end

    assert immediate_owner.avatar_with_immediate_analysis.blob.analyzed?
  end

  test "generic immediate analysis persists existing blob metadata when local io is available" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    blob = create_memory_blob(filename: "existing.txt", data: "SIGNED")
    blob.analyzed = false
    blob.local_io = StringIO.new("SIGNED")
    save_calls = 0

    blob.singleton_class.alias_method :save_without_counting!, :save!
    blob.define_singleton_method(:save!) do
      save_calls += 1
      save_without_counting!
    end

    owner.avatar_with_immediate_analysis.attach(blob)

    assert blob.analyzed?
    assert_equal 1, save_calls
  end

  test "variant records use the configured generic owner backend" do
    record = ActiveStorage.variant_record_class.create_or_find_by!(blob_id: 123, variation_digest: "abc") do |variant_record|
      variant_record.image.attach(io: StringIO.new("VARIANT"), filename: "variant.txt", content_type: "text/plain")
    end

    assert record.image.attached?
    assert_equal "VARIANT", record.image.download
  end

  test "previews attach preview images to generic blobs" do
    previewer = Class.new(ActiveStorage::Previewer) do
      def self.accept?(blob)
        blob.content_type == "application/pdf"
      end

      def preview(**)
        yield io: StringIO.new("PREVIEW"), filename: "preview.png", content_type: "image/png"
      end
    end
    previous_previewers = ActiveStorage.previewers
    ActiveStorage.previewers = [ previewer ]
    blob = create_memory_blob(filename: "document.pdf", data: "PDF", content_type: "application/pdf")

    blob.preview({}).processed

    assert blob.preview_image.attached?
    assert_equal "PREVIEW", blob.preview_image.download
  ensure
    ActiveStorage.previewers = previous_previewers
  end

  test "tracked variants create and reuse generic variant records" do
    with_variant_tracking do
      owner = @owner_class.new(name: "Dorian")
      owner.save!
      owner.avatar_with_variants.attach(io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg")

      assert_difference -> { ActiveStorage.variant_record_class.records.size }, +1 do
        owner.avatar_with_variants.variant(:thumb).processed
      end

      record = ActiveStorage.variant_record_class.records.first

      assert record.image.attached?
      assert_no_difference -> { ActiveStorage.variant_record_class.records.size } do
        owner.avatar_with_variants.variant(:thumb).processed
      end
      assert_equal record, ActiveStorage.variant_record_class.records.first
    end
  end

  test "destroying tracked generic blobs destroys variant records" do
    with_variant_tracking do
      owner = @owner_class.new(name: "Dorian")
      owner.save!
      owner.avatar_with_variants.attach(io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg")
      owner.avatar_with_variants.variant(:thumb).processed

      record = ActiveStorage.variant_record_class.records.first
      variant_blob = record.image.blob

      assert_difference -> { ActiveStorage.variant_record_class.records.size }, -1 do
        assert_enqueued_with(job: ActiveStorage::PurgeJob) do
          owner.avatar_with_variants.purge
        end
      end

      assert_not record.persisted?
      assert_empty ActiveStorage.attachment_class.where(record_type: record.class.name, record_id: record.id, name: "image").to_a

      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)

      assert_not variant_blob.persisted?
    end
  end

  test "named variants resolve through active model reflections" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar_with_variants.attach(io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg")

    assert_instance_of ActiveStorage::Variant, owner.avatar_with_variants.variant(:thumb)
  end

  private
    def create_memory_blob(filename: "hello.txt", data: "Hello world!", content_type: "text/plain")
      ActiveStorage.blob_class.create_and_upload!(
        io: StringIO.new(data),
        filename: filename,
        content_type: content_type,
        identify: false
      )
    end

    def with_variant_tracking
      previous_track_variants = ActiveStorage.track_variants
      ActiveStorage.track_variants = true
      yield
    ensure
      ActiveStorage.track_variants = previous_track_variants
    end
end
