# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::GenericLifecycleTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  test "failed persistence and an erroneous commit preserve pending attachments" do
    [false, true].each do |existing|
      owner = @owner_class.new(name: "Dorian")
      owner.save! if existing
      owner.avatar = lifecycle_upload("pending")
      change = owner.attachment_changes.fetch("avatar")

      assert_equal false, owner.run_callbacks(:save) { false }
      owner.run_callbacks(:commit) { true }

      assert_same change, owner.attachment_changes["avatar"]
      assert_not change.blob.persisted?
      assert_not change.blob.service.exist?(change.blob.key)
    end
  end

  test "a successful owner save without an id does not write attachment metadata" do
    owner = @owner_class.new(name: "Dorian")
    owner.avatar = lifecycle_upload("avatar")
    owner.photos = [lifecycle_upload("photo")]
    changes = owner.attachment_changes.dup

    error = assert_raises(ActiveStorage::OwnerContractMissing) do
      owner.run_callbacks(:save) { true }
    end

    assert_match "must assign an id before saving attachments", error.message
    assert_empty ActiveStorage.blob_class.records
    assert_empty ActiveStorage.attachment_class.records
    assert_equal changes, owner.attachment_changes
    owner.save!
    assert_equal "avatar", owner.avatar.download
    assert_equal ["photo"], owner.photos.blobs.map(&:download)
  end

  test "replacing an unsaved has many assignment uploads only its saved selection" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("discarded")]
    discarded = owner.photos.blobs.first
    owner.photos = [lifecycle_upload("selected")]
    owner.save!

    assert_equal ["selected"], owner.photos.blobs.map(&:download)
    assert_not discarded.persisted?
    assert_not discarded.service.exist?(discarded.key)
  end

  test "replacing appended uploads uploads only the retained blob" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos.attach(lifecycle_upload("discarded"))
    discarded = owner.photos.blobs.first
    owner.photos.attach(lifecycle_upload("selected"))
    owner.photos = [owner.photos.blobs.last]
    owner.save!

    assert_equal ["selected"], owner.photos.blobs.map(&:download)
    assert_not discarded.persisted?
    assert_not discarded.service.exist?(discarded.key)
  end

  test "appending unsaved uploads keeps analysis from running before their files exist" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.photos.attach(lifecycle_upload("first"))
    owner.photos.attach(lifecycle_upload("second"))
    blobs = owner.photos.blobs
    download_analysis_input = ->(event) do
      job = event.payload[:job]
      job.arguments.first.download if job.is_a?(ActiveStorage::AnalyzeJob)
    end

    ActiveSupport::Notifications.subscribed(download_analysis_input, "perform_start.active_job") do
      perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
        owner.save!
        blobs.each { |blob| assert_not blob.service.exist?(blob.key) }
        commit_lifecycle(owner)
      end
    end

    assert_equal ["first", "second"], owner.photos.blobs.map(&:download)
  end

  test "appending an upload still analyzes existing has many blobs" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.photos.attach(create_memory_blob(data: "stored"))
    owner.photos.attach(lifecycle_upload("pending"))
    analysis_inputs = []
    download_analysis_input = ->(event) do
      job = event.payload[:job]
      analysis_inputs << job.arguments.first.download if job.is_a?(ActiveStorage::AnalyzeJob)
    end

    ActiveSupport::Notifications.subscribed(download_analysis_input, "perform_start.active_job") do
      perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
        owner.save!
        assert_equal ["stored"], analysis_inputs
        commit_lifecycle(owner)
      end
    end

    assert_equal ["stored"], analysis_inputs
    assert_equal ["stored", "pending"], owner.photos.blobs.map(&:download)
  end

  test "committing an earlier has many change consumes uploads carried by a pending assignment" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.photos = [lifecycle_upload("first")]
    owner.save!
    first = owner.photos.blobs.first
    owner.photos = owner.photos.blobs + [lifecycle_upload("second")]
    pending = owner.attachment_changes.fetch("photos")

    commit_lifecycle(owner)

    assert_same pending, owner.attachment_changes["photos"]
    assert_equal "first", first.download
    assert_empty pending.pending_uploads.select { |source| source.blob == first }
    owner.save!
    commit_lifecycle(owner)
    assert_equal ["first", "second"], owner.photos.blobs.map(&:download)
  end

  test "saved IO survives reassignment through its blob before commit" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("first")
    owner.save!
    blob = owner.avatar.blob
    owner.avatar = blob
    owner.save!
    commit_lifecycle(owner)

    assert_equal "first", owner.avatar.download
    assert_empty owner.attachment_changes
  end

  test "saved IO follows its blob across attachment names before commit" do
    [:icon, :photos].each do |name|
      owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
      owner.avatar = lifecycle_upload("transferred")
      owner.save!
      blob = owner.avatar.blob
      owner.public_send("#{name}=", name == :photos ? [blob] : blob)
      owner.save!
      owner.avatar.detach
      commit_lifecycle(owner)

      surviving_blob = name == :photos ? owner.photos.blobs.first : owner.icon.blob
      assert_equal "transferred", surviving_blob.download
      assert_empty owner.attachment_changes
    end
  end

  test "moving a pending upload to another name defers analysis until the file exists" do
    @owner_class.attachment_reflections["avatar"].options[:analyze] = :later
    [:icon, :photos].product([false, true]).each do |name, save_source|
      owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
      owner.avatar = lifecycle_upload("transferred")
      owner.save! if save_source
      blob = owner.avatar.blob
      owner.public_send("#{name}=", name == :photos ? [blob] : blob)
      download_analysis_input = ->(event) do
        job = event.payload[:job]
        job.arguments.first.download if job.is_a?(ActiveStorage::AnalyzeJob)
      end

      ActiveSupport::Notifications.subscribed(download_analysis_input, "perform_start.active_job") do
        perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
          owner.save!
          owner.avatar.detach
          commit_lifecycle(owner)
        end
      end

      assert_equal "transferred", blob.download
      surviving_blob = name == :photos ? owner.photos.blobs.first : owner.icon.blob
      assert surviving_blob.analyzed?
      owner.public_send("#{name}=", name == :photos ? [surviving_blob] : surviving_blob)
      owner.save!
      commit_lifecycle(owner)
      assert ActiveStorage.blob_class.find(blob.id).analyzed?
    end
  end

  test "committing an upload keeps cached analysis metadata for subsequent saves" do
    @owner_class.attachment_reflections["avatar"].options[:analyze] = :later
    @owner_class.attachment_reflections["photos"].options[:analyze] = :later
    [:avatar, :photos].each do |name|
      owner = @owner_class.new(name: "Dorian")
      owner.public_send("#{name}=", name == :photos ? [lifecycle_upload("analyzed")] : lifecycle_upload("analyzed"))
      blob = name == :photos ? owner.photos.blobs.first : owner.avatar.blob
      owner.save!

      assert blob.analyzed?
      owner.public_send("#{name}=", name == :photos ? [blob] : blob)
      owner.save!

      assert ActiveStorage.blob_class.find(blob.id).analyzed?
      assert_equal "analyzed", blob.download
    end
  end

  test "committing a rebound attachment uploads only the blob still referenced by its row" do
    @owner_class.attachment_reflections["photos"].options[:analyze] = :later
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.photos = [lifecycle_upload("removed"), lifecycle_upload("surviving")]
    owner.save!
    removed, surviving = owner.photos.blobs
    first_attachment, second_attachment = owner.photos.attachments
    ActiveStorage.attachment_class.find(first_attachment.id).update!(blob_id: surviving.id)
    ActiveStorage.attachment_class.find(second_attachment.id).delete
    uploaded_keys = []
    track_uploads = ->(event) { uploaded_keys << event.payload.fetch(:key) }

    ActiveSupport::Notifications.subscribed(track_uploads, "service_upload.active_storage") do
      commit_lifecycle(owner)
    end

    assert_equal [surviving.key], uploaded_keys
    assert_not removed.service.exist?(removed.key)
    assert_equal ["surviving"], owner.photos.blobs.map(&:download)
    assert ActiveStorage.blob_class.find(surviving.id).analyzed?
    assert_empty owner.attachment_changes
  end

  test "repeated saves retain deferred replacement purges" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("original")
    owner.save!
    original = owner.icon.blob
    defer_lifecycle_commits(owner)
    owner.icon = lifecycle_upload("replacement")
    owner.save!
    owner.save!

    assert original.persisted?
    commit_lifecycle(owner)
    assert_not original.persisted?
    assert_not original.service.exist?(original.key)
    assert_equal "replacement", owner.icon.download
  end

  test "purging or detaching before commit cancels the removed attachment upload" do
    [:avatar, :photos].product([:purge, :purge_later, :detach]).each do |name, operation|
      owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
      owner.public_send("#{name}=", name == :photos ? [lifecycle_upload("pending")] : lifecycle_upload("pending"))
      owner.save!
      blob = name == :photos ? owner.photos.blobs.first : owner.avatar.blob
      owner.public_send(name).public_send(operation)
      commit_lifecycle(owner)

      assert_not blob.service.exist?(blob.key), "#{name}.#{operation} uploaded a removed attachment"
      assert_empty ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id, name: name.to_s).to_a
    end
  end

  test "cancelling an unsaved replacement preserves an earlier saved upload" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("saved")
    owner.save!
    saved = owner.avatar.blob
    owner.avatar = lifecycle_upload("unsaved")
    owner.avatar.detach
    commit_lifecycle(owner)

    assert_equal "saved", saved.download
  end

  test "detaching a pending has many selection removes only its persisted attachments" do
    owner = @owner_class.new(name: "Dorian")
    owner.photos = [lifecycle_upload("unselected"), lifecycle_upload("selected")]
    owner.save!
    unselected, selected = owner.photos.blobs
    owner.photos = [selected, lifecycle_upload("unsaved")]
    unsaved = owner.photos.blobs.last

    assert_no_enqueued_jobs { owner.photos.detach }

    assert_equal [unselected.id], owner.photos.blobs.map(&:id)
    assert_equal "selected", selected.download
    assert selected.persisted?
    assert_not unsaved.persisted?
    assert_not unsaved.service.exist?(unsaved.key)
    assert_empty owner.attachment_changes
    owner.save!
    assert_equal ["unselected"], owner.photos.blobs.map(&:download)
  end

  test "successful destruction clears cached attachment readers before committing purges" do
    owner = @owner_class.new(name: "Dorian")
    owner.icon = lifecycle_upload("icon")
    owner.favorites = [ lifecycle_upload("favorite") ]
    owner.save!
    icon = owner.icon_blob
    favorites = owner.favorites_blobs.to_a
    assert owner.icon_attachment.persisted?
    assert_equal 1, owner.favorites_attachments.to_a.size
    assert owner.icon.attached?
    assert owner.favorites.attached?
    defer_lifecycle_commits(owner)

    assert owner.destroy

    assert_empty ActiveStorage.attachment_class.where(record_type: owner.class.name, record_id: owner.id).to_a
    assert_not owner.icon.attached?
    assert_nil owner.icon_attachment
    assert_nil owner.icon_blob
    assert_not owner.favorites.attached?
    assert_empty owner.favorites_attachments.to_a
    assert_empty owner.favorites_blobs.to_a
    assert_empty owner.attachment_changes
    assert icon.persisted?
    assert favorites.all?(&:persisted?)

    commit_lifecycle(owner)

    assert_not icon.persisted?
    assert favorites.none?(&:persisted?)
  end

  test "failed destruction retains pending assignments" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("avatar")
    owner.photos = [ lifecycle_upload("photo") ]
    changes = owner.attachment_changes.dup

    assert_equal false, owner.run_callbacks(:destroy) { false }
    commit_lifecycle(owner)

    changes.each do |name, change|
      assert_same change, owner.attachment_changes[name]
    end
    owner.save!
    assert_equal "avatar", owner.avatar.download
    assert_equal [ "photo" ], owner.photos.blobs.map(&:download)
  end

  test "aborted destruction retains the pending assignment" do
    owner = @owner_class.new(name: "Dorian")
    owner.save!
    owner.avatar = lifecycle_upload("pending")
    change = owner.attachment_changes.fetch("avatar")
    @owner_class.before_destroy { throw :abort }

    assert_equal false, owner.destroy
    assert_same change, owner.attachment_changes["avatar"]
    owner.save!
    assert_equal "pending", owner.avatar.download
  end

  test "reload preserves saved upload work and dup does not inherit it" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("saved")
    owner.save!
    blob = owner.avatar.blob
    copy = owner.dup
    commit_lifecycle(copy)
    assert_not blob.service.exist?(blob.key)

    owner.reload
    commit_lifecycle(owner)
    assert_equal "saved", blob.download
  end

  test "a false commit neither uploads nor discards saved work" do
    owner = defer_lifecycle_commits(@owner_class.new(name: "Dorian"))
    owner.avatar = lifecycle_upload("saved")
    owner.save!
    blob = owner.avatar.blob
    commit_lifecycle(owner, false)
    assert_not blob.service.exist?(blob.key)
    assert owner.attachment_changes.any?

    commit_lifecycle(owner)
    assert_equal "saved", blob.download
  end
end
