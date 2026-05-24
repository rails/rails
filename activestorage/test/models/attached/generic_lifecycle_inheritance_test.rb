# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::GenericLifecycleInheritanceTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  teardown do
    @lifecycle_test_constants&.reverse_each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
  end

  test "subclasses adding transaction callbacks upload inherited and newly declared attachments" do
    parent = lifecycle_owner_class("LifecycleParent", commit_callbacks: false)
    child = lifecycle_subclass(parent, "LifecycleChild")
    child.define_model_callbacks :commit, :rollback
    child.has_one_attached :extra
    owner = defer_lifecycle_commits(child.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("inherited")
    owner.extra = lifecycle_upload("declared")
    owner.save!

    assert_not owner.avatar.blob.service.exist?(owner.avatar.blob.key)
    assert_not owner.extra.blob.service.exist?(owner.extra.blob.key)
    commit_lifecycle(owner)
    assert_equal "inherited", owner.avatar.download
    assert_equal "declared", owner.extra.download
    assert_equal 1, child._commit_callbacks.count { |callback| callback.filter == :commit_attachment_changes }
    assert_equal 1, child._rollback_callbacks.count { |callback| callback.filter == :rollback_attachment_changes }
  end

  test "parent attachment declarations install transaction handlers on existing subclasses" do
    parent = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy
      attr_accessor :id

      def self.find(id)
        new(id: id)
      end

      def persisted?
        id.present?
      end
    end
    lifecycle_constant("LateLifecycleParent", parent)
    child = lifecycle_constant("EarlyLifecycleChild", Class.new(parent))
    child.define_model_callbacks :commit, :rollback
    parent.has_one_attached :avatar
    owner = child.new(id: 1)
    owner.avatar = lifecycle_upload("inherited")

    owner.run_callbacks(:save) { true }
    assert_not owner.avatar.blob.service.exist?(owner.avatar.blob.key)
    owner.run_callbacks(:commit) { true }

    assert_equal "inherited", owner.avatar.download
    assert_equal 1, child._commit_callbacks.count { |callback| callback.filter == :commit_attachment_changes }
    assert_equal 1, child._rollback_callbacks.count { |callback| callback.filter == :rollback_attachment_changes }
  end

  test "redefining transaction callbacks installs symbol handlers once for generated runners" do
    owner_class = lifecycle_owner_class("RedefinedLifecycleOwner", rollback_callbacks: true)
    silence_warnings do
      2.times { owner_class.define_model_callbacks :commit, :rollback }
    end
    owner_class.has_one_attached :extra
    owner = defer_lifecycle_commits(owner_class.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("saved")
    owner.save!
    blob = owner.avatar.blob
    owner.singleton_class.remove_method(:run_callbacks)

    assert_equal 1, owner_class._commit_callbacks.count { |callback| callback.filter == :commit_attachment_changes }
    assert_equal 1, owner_class._rollback_callbacks.count { |callback| callback.filter == :rollback_attachment_changes }
    assert_no_enqueued_jobs do
      owner.send(:_run_commit_callbacks) { false }
    end
    assert_not blob.service.exist?(blob.key)

    uploaded_keys = capture_lifecycle_uploads(blob.service) do
      owner.send(:_run_commit_callbacks) { true }
      owner.send(:_run_commit_callbacks) { true }
    end
    assert_equal [ blob.key ], uploaded_keys
    assert_equal "saved", blob.download
  end

  test "attachment save and destroy handlers retain the first declaration registration order" do
    owner_class = lifecycle_constant("OrderedLifecycleOwner", Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations::Callbacks
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy, :commit
      attr_accessor :id

      class << self
        attr_accessor :records

        def find(id)
          records.fetch(id) { raise ActiveStorage::RecordNotFound }
        end
      end

      def persisted?
        @persisted == true
      end

      def save
        return false unless valid?

        run_callbacks(:save) do
          self.id ||= 1
          self.class.records[id] = self
          @persisted = true
        end
        run_callbacks(:commit) { true }
      end

      def destroy
        run_callbacks(:destroy) do
          self.class.records.delete(id)
          @persisted = false
          true
        end
        run_callbacks(:commit) { true }
      end
    end)
    owner_class.records = {}
    trace = []
    register_callbacks = ->(position) do
      [:save, :destroy].each do |event|
        owner_class.public_send("after_#{event}") do
          names = ActiveStorage.attachment_class.where(record_type: self.class.name, record_id: id).map(&:name).sort
          trace << [event, position, persisted?, names]
        end
      end
    end

    register_callbacks.call(:before)
    owner_class.has_one_attached :avatar, dependent: false
    register_callbacks.call(:between)
    owner_class.has_many_attached :photos, dependent: false
    register_callbacks.call(:after)
    owner = owner_class.new
    owner.avatar = create_memory_blob
    owner.photos = [create_memory_blob]

    assert owner.save
    assert owner.destroy

    assert_equal [
      [:save, :before, true, []],
      [:save, :between, true, ["avatar", "photos"]],
      [:save, :after, true, ["avatar", "photos"]],
      [:destroy, :before, false, ["avatar", "photos"]],
      [:destroy, :between, false, []],
      [:destroy, :after, false, []]
    ], trace
    assert_equal 1, owner_class._save_callbacks.count { |callback| callback.filter == :save_attachment_changes }
    assert_equal 1, owner_class._destroy_callbacks.count { |callback| callback.filter == :destroy_owner_attachments }
  end

  test "callback count is independent of attachment declarations" do
    [ false, true ].each do |commit_callbacks|
      owner_class = lifecycle_owner_class("CountedLifecycleOwner", commit_callbacks: commit_callbacks, rollback_callbacks: commit_callbacks)
      count = owner_class.__callbacks.values.sum(&:count)
      20.times { |index| owner_class.has_one_attached "extra_#{index}" }

      assert_equal count, owner_class.__callbacks.values.sum(&:count)
      assert_equal 1, owner_class._save_callbacks.count { |callback| callback.filter == :save_attachment_changes }
      assert_equal 1, owner_class._destroy_callbacks.count { |callback| callback.filter == :destroy_owner_attachments }
    end
  end

  test "new and duplicated owners do not inherit persistence from an existing id" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    unsaved = @owner_class.new(id: owner.id, name: "Basil")
    duplicate = owner.dup

    assert_not unsaved.persisted?
    assert_not unsaved.destroy
    assert owner.persisted?
    assert @owner_class.find(owner.id).persisted?
    assert_not duplicate.persisted?
    assert_nil duplicate.id
  end

  test "failed persistence without commit callbacks preserves dependent purge attachments" do
    owner_class = lifecycle_owner_class("FailedLifecycleOwner", commit_callbacks: false)

    [ :icon, :favorites ].each do |name|
      owner = owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "original")
      owner.save!
      original = lifecycle_blobs(owner, name).first
      assign_lifecycle_attachment(owner, name, "replacement")
      pending = owner.attachment_changes.fetch(name.to_s)
      replacement = lifecycle_blobs(owner, name).first

      assert_equal false, owner.run_callbacks(:save) { false }

      assert_same pending, owner.attachment_changes[name.to_s]
      assert original.persisted?
      assert_equal "original", original.download
      assert_equal [ original.id ], stored_lifecycle_attachments(owner, name).map(&:blob_id)
      assert_not replacement.persisted?
      assert_not replacement.service.exist?(replacement.key)
    end
  end

  test "owners must report persistence during save callbacks before attachment metadata is written" do
    [false, true].each do |commit_callbacks|
      owner_class = lifecycle_owner_class("LatePersistenceOwner", commit_callbacks: commit_callbacks)
      owner = owner_class.new(name: "Dorian")
      owner.avatar = lifecycle_upload("avatar")
      owner.photos = [lifecycle_upload("photo")]
      changes = owner.attachment_changes.dup

      error = assert_raises(ActiveStorage::OwnerContractMissing) do
        owner.run_callbacks(:save) do
          owner.id = owner_class.id_sequence.increment
          owner_class.store[owner.id] = owner.attributes.deep_dup
          true
        end
      end

      assert_match "must be persisted during after_save callbacks", error.message
      assert_empty ActiveStorage.blob_class.records
      assert_empty ActiveStorage.attachment_class.records
      assert_equal changes, owner.attachment_changes

      owner.save!
      assert_equal "avatar", owner.avatar.download
      assert_equal ["photo"], owner.photos.blobs.map(&:download)
      perform_enqueued_jobs { owner.destroy }
    end
  end

  test "rollback cancels saved side effects while retaining current assignments for retry" do
    owner_class = lifecycle_owner_class("RollbackLifecycleOwner", rollback_callbacks: true)

    [ :icon, :favorites ].each do |name|
      owner = owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "original")
      owner.save!
      original = lifecycle_blobs(owner, name).first
      defer_lifecycle_commits(owner)
      snapshots = [ owner_class, ActiveStorage.blob_class, ActiveStorage.attachment_class ].index_with { |model| model.store.dup }
      assign_lifecycle_attachment(owner, name, "replacement")
      pending = owner.attachment_changes.fetch(name.to_s)
      replacement = lifecycle_blobs(owner, name).first
      owner.save!
      snapshots.each do |model, snapshot|
        model.store.clear
        snapshot.each { |id, attributes| model.store[id] = attributes }
      end
      owner.run_callbacks(:rollback) { true }

      commit_lifecycle(owner)

      assert_same pending, owner.attachment_changes[name.to_s]
      assert original.persisted?
      assert_equal "original", original.download
      assert_not replacement.persisted?
      assert_not replacement.service.exist?(replacement.key)

      owner.save!
      commit_lifecycle(owner)
      assert_equal [ "replacement" ], lifecycle_blobs(owner, name).map(&:download)
      assert_not original.persisted?
      assert_not original.service.exist?(original.key)
    end
  end

  test "multiple saved replacements upload surviving attachments and purge every superseded blob" do
    [ :icon, :favorites ].each do |name|
      owner = @owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "original")
      owner.save!
      original = lifecycle_blobs(owner, name).first
      defer_lifecycle_commits(owner)
      assign_lifecycle_attachment(owner, name, "intermediate")
      owner.save!
      intermediate = lifecycle_blobs(owner, name).first
      assign_lifecycle_attachment(owner, name, "final")
      owner.save!
      final = lifecycle_blobs(owner, name).first

      uploaded_keys = capture_lifecycle_uploads(final.service) { commit_lifecycle(owner) }

      assert_equal [ final.key ], uploaded_keys
      assert_equal [ "final" ], lifecycle_blobs(owner, name).map(&:download)
      assert_equal [ final.id ], stored_lifecycle_attachments(owner, name).map(&:blob_id)
      [ original, intermediate ].each do |blob|
        assert_not blob.persisted?
        assert_not blob.service.exist?(blob.key)
      end
    end
  end

  test "saved deletion and recreation retain deferred purges" do
    [ :icon, :favorites ].each do |name|
      owner = @owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "original")
      owner.save!
      original = lifecycle_blobs(owner, name).first
      defer_lifecycle_commits(owner)
      assign_lifecycle_attachment(owner, name, nil)
      owner.save!
      assign_lifecycle_attachment(owner, name, "replacement")
      owner.save!
      replacement = lifecycle_blobs(owner, name).first

      uploaded_keys = capture_lifecycle_uploads(replacement.service) { commit_lifecycle(owner) }

      assert_equal [ replacement.key ], uploaded_keys
      assert_equal [ "replacement" ], lifecycle_blobs(owner, name).map(&:download)
      assert_not original.persisted?
      assert_not original.service.exist?(original.key)
    end
  end

  test "deleting a saved replacement before commit cancels every upload and retains purges" do
    [ :icon, :favorites ].each do |name|
      owner = @owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "original")
      owner.save!
      original = lifecycle_blobs(owner, name).first
      defer_lifecycle_commits(owner)
      assign_lifecycle_attachment(owner, name, "replacement")
      owner.save!
      replacement = lifecycle_blobs(owner, name).first
      assign_lifecycle_attachment(owner, name, nil)
      owner.save!

      uploaded_keys = capture_lifecycle_uploads(replacement.service) { commit_lifecycle(owner) }

      assert_empty uploaded_keys
      assert_empty stored_lifecycle_attachments(owner, name)
      [ original, replacement ].each do |blob|
        assert_not blob.persisted?
        assert_not blob.service.exist?(blob.key)
      end
    end
  end

  test "a later attachment save failure preserves earlier successfully saved upload work" do
    [ :icon, :favorites ].each do |name|
      owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
      assign_lifecycle_attachment(owner, name, "saved")
      owner.save!
      saved = lifecycle_blobs(owner, name).first
      assign_lifecycle_attachment(owner, name, "failed")
      failed = owner.attachment_changes.fetch(name.to_s)
      attachment = failed.respond_to?(:attachments) ? failed.attachments.first : failed.attachment
      attachment.define_singleton_method(:save!) { raise ActiveStorage::RecordNotSaved.new("attachment failed", self) }

      assert_raises(ActiveStorage::RecordNotSaved) { owner.save! }
      commit_lifecycle(owner)

      assert_equal "saved", saved.download
      assert_same failed, owner.attachment_changes[name.to_s]
      assert_equal [ saved.id ], stored_lifecycle_attachments(owner, name).map(&:blob_id)

      attachment.singleton_class.remove_method(:save!)
      owner.save!
      commit_lifecycle(owner)
      assert_equal [ "failed" ], lifecycle_blobs(owner, name).map(&:download)
      assert_not saved.persisted?
    end
  end

  test "a backend transaction rolls back every attachment name when one save fails" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("original-icon")
    owner.favorites = [lifecycle_upload("original-favorite")]
    owner.save!
    originals = [owner.icon.blob, owner.favorites.blobs.first]
    defer_lifecycle_commits(owner)
    owner.icon = lifecycle_upload("replacement-icon")
    owner.favorites = [lifecycle_upload("replacement-favorite")]
    changes = owner.attachment_changes.dup
    replacements = [owner.icon.blob, owner.favorites.blobs.first]
    failing_attachment = owner.favorites.attachments.first
    failing_attachment.define_singleton_method(:save!) { raise ActiveStorage::RecordNotSaved.new("attachment failed", self) }

    with_transactional_lifecycle_metadata do
      assert_raises(ActiveStorage::RecordNotSaved) { owner.save! }

      assert_equal originals.map(&:id), ActiveStorage.attachment_class.where(record_id: owner.id).map(&:blob_id)
      assert_equal changes, owner.attachment_changes
      assert_no_enqueued_jobs { commit_lifecycle(owner) }
      assert originals.all?(&:persisted?)
      replacements.each do |blob|
        assert_not blob.persisted?
        assert_not blob.service.exist?(blob.key)
      end

      failing_attachment.singleton_class.remove_method(:save!)
      owner.save!
      commit_lifecycle(owner)
    end

    assert_equal "replacement-icon", owner.icon.download
    assert_equal ["replacement-favorite"], owner.favorites.blobs.map(&:download)
    assert originals.none?(&:persisted?)
  end

  test "cleanup destruction failures do not replace the original attachment save error" do
    [:avatar, :photos].each do |name|
      owner = @owner_class.new(name: "Dorian")
      assign_lifecycle_attachment(owner, name, "pending")
      change = owner.attachment_changes.fetch(name.to_s)
      attachment = change.respond_to?(:attachments) ? change.attachments.first : change.attachment
      original_error = ActiveStorage::RecordNotSaved.new("attachment save failed", attachment)
      save_attachment = attachment.method(:save!)
      attachment.define_singleton_method(:save!) do
        save_attachment.call
        raise original_error
      end
      attachment.define_singleton_method(:destroy) { raise "cleanup failed" }

      error = assert_raises(ActiveStorage::RecordNotSaved) { owner.save! }

      assert_same original_error, error
      assert_same change, owner.attachment_changes[name.to_s]
      assert_not attachment.blob.service.exist?(attachment.blob.key)
    end
  end

  private
    def lifecycle_constant(name, klass)
      (@lifecycle_test_constants ||= []) << name
      Object.const_set(name, klass)
    end

    def lifecycle_owner_class(name, **options)
      (@lifecycle_test_constants ||= []) << name
      ActiveStorage::ActiveModelOwnerFixture.define!(name: name, **options)
    end

    def lifecycle_subclass(parent, name)
      lifecycle_constant(name, Class.new(parent)).tap(&:reset)
    end

    def assign_lifecycle_attachment(owner, name, content)
      value = lifecycle_upload(content) if content
      value = Array.wrap(value) if owner.class.reflect_on_attachment(name).macro == :has_many_attached
      owner.public_send("#{name}=", value)
    end

    def lifecycle_blobs(owner, name)
      attachment = owner.public_send(name)
      attachment.is_a?(ActiveStorage::Attached::Many) ? attachment.blobs : Array(attachment.blob)
    end

    def stored_lifecycle_attachments(owner, name)
      ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: name.to_s).to_a
    end

    def capture_lifecycle_uploads(service, &block)
      keys = []
      upload = service.method(:upload)
      service.stub(:upload, ->(key, io, **options) { keys << key; upload.call(key, io, **options) }, &block)
      keys
    end

    def with_transactional_lifecycle_metadata(&block)
      depth = 0
      transaction = ->(&operation) do
        if depth.positive?
          operation.call
        else
          models = [ActiveStorage.blob_class, ActiveStorage.attachment_class]
          snapshots = models.index_with { |model| model.store.each_pair.to_h.deep_dup }
          depth += 1
          begin
            operation.call
          rescue StandardError
            snapshots.each do |model, snapshot|
              model.store.clear
              snapshot.each { |id, attributes| model.store[id] = attributes }
            end
            raise
          ensure
            depth -= 1
          end
        end
      end
      ActiveStorage.attachment_class.stub(:transaction, transaction, &block)
    end
end
