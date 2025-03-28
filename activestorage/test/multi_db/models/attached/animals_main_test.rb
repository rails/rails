# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::ManyAttachedAnimalsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = AnimalsUser.create!(name: "Josh")
  end

  teardown do
    ActiveStorage::AnimalsBlob.all.each(&:delete)
  end

  test "attaching existing blobs to an existing record for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s

    assert_not_empty @user.highlights_attachments
    assert_equal 2, @user.highlights_blobs.count
  end

  test "attaching existing blobs from signed IDs to an existing record for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg").signed_id, create_animals_blob(filename: "town.jpg").signed_id
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from Hashes to an existing record for main" do
    @user.highlights.attach(
      { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpeg" },
      { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg" })

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from uploaded files to an existing record for main" do
    @user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs to an existing, changed record for main" do
    @user.name = "Tina"
    assert_predicate @user, :changed?

    @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert_predicate @user, :will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs from signed IDs to an existing, changed record for main" do
    @user.name = "Tina"
    assert_predicate @user, :changed?

    @user.highlights.attach create_animals_blob(filename: "funky.jpg").signed_id, create_animals_blob(filename: "town.jpg").signed_id
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert_predicate @user, :will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from Hashes to an existing, changed record for main" do
    @user.name = "Tina"
    assert_predicate @user, :changed?

    @user.highlights.attach(
      { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpeg" },
      { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg" })

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert_predicate @user, :will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from uploaded files to an existing, changed record for main" do
    @user.name = "Tina"
    assert_predicate @user, :changed?

    @user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert_predicate @user, :will_save_change_to_name?

    @user.save!
    assert_equal "racecar.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from uploaded files to an existing, changed record one at a time for main" do
    @user.name = "Tina"
    assert_predicate @user, :changed?

    @user.highlights.attach fixture_file_upload("racecar.jpg")
    @user.highlights.attach fixture_file_upload("video.mp4")
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert_predicate @user, :will_save_change_to_name?
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)

    @user.save!
    assert_equal "racecar.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
  end

  test "attaching new blobs within a transaction uploads all the files for main" do
    @user.highlights.attach fixture_file_upload("image.gif")

    AnimalsRecord.transaction do
      @user.highlights.attach fixture_file_upload("racecar.jpg")
      @user.highlights.attach fixture_file_upload("video.mp4")
    end

    assert_equal "image.gif", @user.highlights.first.filename.to_s
    assert_equal "racecar.jpg", @user.highlights.second.filename.to_s
    assert_equal "video.mp4", @user.highlights.third.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.third.key)
  end

  test "attaching many new blobs within a transaction uploads all the files for main" do
    AnimalsRecord.transaction do
      @user.highlights.attach [fixture_file_upload("image.gif"), fixture_file_upload("racecar.jpg")]
      @user.highlights.attach fixture_file_upload("video.mp4")
    end

    assert_equal "image.gif", @user.highlights.first.filename.to_s
    assert_equal "racecar.jpg", @user.highlights.second.filename.to_s
    assert_equal "video.mp4", @user.highlights.third.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.third.key)
  end

  test "attaching many new blobs within a transaction on a dirty record uploads all the files for main" do
    @user.name = "Tina"

    AnimalsRecord.transaction do
      @user.highlights.attach fixture_file_upload("image.gif")
      @user.highlights.attach fixture_file_upload("racecar.jpg")
    end

    @user.highlights.attach fixture_file_upload("video.mp4")
    @user.save

    assert_equal "image.gif", @user.highlights.first.filename.to_s
    assert_equal "racecar.jpg", @user.highlights.second.filename.to_s
    assert_equal "video.mp4", @user.highlights.third.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.third.key)
  end

  test "attaching many new blobs within a transaction on a new record uploads all the files for main" do
    user = AnimalsUser.create!(name: "John") do |user|
      user.highlights.attach(io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpeg")
      user.highlights.attach(io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg")
    end

    assert_equal 2, user.highlights.count
    assert_equal "funky.jpg", user.highlights.first.filename.to_s
    assert_equal "town.jpg", user.highlights.second.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)
  end

  test "attaching new blobs within a transaction create the exact amount of records for main" do
    assert_difference -> { ActiveStorage::AnimalsBlob.count }, +2 do
      AnimalsRecord.transaction do
        @user.highlights.attach fixture_file_upload("racecar.jpg")
        @user.highlights.attach fixture_file_upload("video.mp4")
      end
    end

    assert_equal 2, @user.highlights.count
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
  end

  test "attaching existing blobs to an existing record one at a time for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg")
    @user.highlights.attach create_animals_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s

    @user.reload
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "updating an existing record to attach existing blobs for main" do
    @user.update! highlights: [ create_animals_file_blob(filename: "racecar.jpg"), create_animals_file_blob(filename: "video.mp4") ]
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "updating an existing record to attach existing blobs from signed IDs for main" do
    @user.update! highlights: [ create_animals_blob(filename: "funky.jpg").signed_id, create_animals_blob(filename: "town.jpg").signed_id ]
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "successfully updating an existing record to attach new blobs from uploaded files for main" do
    @user.highlights = [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ]
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)

    @user.save!
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
  end

  test "unsuccessfully updating an existing record to attach new blobs from uploaded files for main" do
    assert_not @user.update(name: "", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ])
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
  end

  test "replacing existing, dependent attachments on an existing record via assign and attach for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |old_blobs|
      @user.highlights.attach old_blobs

      @user.highlights = []
      assert_not @user.highlights.attached?

      perform_enqueued_jobs do
        @user.highlights.attach create_animals_blob(filename: "whenever.jpg"), create_animals_blob(filename: "wherever.jpg")
      end

      assert_equal "whenever.jpg", @user.highlights.first.filename.to_s
      assert_equal "wherever.jpg", @user.highlights.second.filename.to_s
      assert_not ActiveStorage::AnimalsBlob.exists?(old_blobs.first.id)
      assert_not ActiveStorage::AnimalsBlob.exists?(old_blobs.second.id)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(old_blobs.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(old_blobs.second.key)
    end
  end

  test "replacing existing, independent attachments on an existing record via assign and attach for main" do
    @user.vlogs.attach create_animals_blob(filename: "funky.mp4"), create_animals_blob(filename: "town.mp4")

    @user.vlogs = []
    assert_not @user.vlogs.attached?

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.vlogs.attach create_animals_blob(filename: "whenever.mp4"), create_animals_blob(filename: "wherever.mp4")
    end

    assert_equal "whenever.mp4", @user.vlogs.first.filename.to_s
    assert_equal "wherever.mp4", @user.vlogs.second.filename.to_s
  end

  test "replacing attachments with an empty list for main" do
    @user.highlights = []
    assert_empty @user.highlights
  end

  test "replacing attachments with a list containing empty items for main" do
    @user.highlights = [""]
    assert_empty @user.highlights
  end

  test "replacing attachments with a list containing a mixture of empty and present items for main" do
    @user.highlights = [ "", fixture_file_upload("racecar.jpg") ]
    assert_equal 1, @user.highlights.size
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
  end

  test "successfully updating an existing record to replace existing, dependent attachments for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |old_blobs|
      @user.highlights.attach old_blobs

      perform_enqueued_jobs do
        @user.update! highlights: [ create_animals_blob(filename: "whenever.jpg"), create_animals_blob(filename: "wherever.jpg") ]
      end

      assert_equal "whenever.jpg", @user.highlights.first.filename.to_s
      assert_equal "wherever.jpg", @user.highlights.second.filename.to_s
      assert_not ActiveStorage::AnimalsBlob.exists?(old_blobs.first.id)
      assert_not ActiveStorage::AnimalsBlob.exists?(old_blobs.second.id)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(old_blobs.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(old_blobs.second.key)
    end
  end

  test "successfully updating an existing record to replace existing, independent attachments for main" do
    @user.vlogs.attach create_animals_blob(filename: "funky.mp4"), create_animals_blob(filename: "town.mp4")

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.update! vlogs: [ create_animals_blob(filename: "whenever.mp4"), create_animals_blob(filename: "wherever.mp4") ]
    end

    assert_equal "whenever.mp4", @user.vlogs.first.filename.to_s
    assert_equal "wherever.mp4", @user.vlogs.second.filename.to_s
  end

  test "unsuccessfully updating an existing record to replace existing attachments for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")

    assert_no_enqueued_jobs do
      assert_not @user.update(name: "", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ])
    end

    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.second.key)
  end

  test "updating an existing record to attach one new blob and one previously-attached blob for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs.first

      perform_enqueued_jobs do
        assert_no_changes -> { @user.highlights_attachments.first.id } do
          @user.update! highlights: blobs
        end
      end

      assert_equal "funky.jpg", @user.highlights.first.filename.to_s
      assert_equal "town.jpg", @user.highlights.second.filename.to_s
      assert ActiveStorage::AnimalsBlob.service.exist?(@user.highlights.first.key)
    end
  end

  test "updating an existing record to remove dependent attachments for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs

      assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blobs.first ] do
        assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blobs.second ] do
          @user.update! highlights: []
        end
      end

      assert_not @user.highlights.attached?
    end
  end

  test "updating an existing record to remove independent attachments for main" do
    [ create_animals_blob(filename: "funky.mp4"), create_animals_blob(filename: "town.mp4") ].tap do |blobs|
      @user.vlogs.attach blobs

      assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
        @user.update! vlogs: []
      end

      assert_not @user.vlogs.attached?
    end
  end

  test "updating an existing record with attachments for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")

    assert_difference -> { @user.reload.highlights.count }, -2 do
      @user.update! highlights: []
    end

    assert_difference -> { @user.reload.highlights.count }, 2 do
      @user.update! highlights: [ create_animals_blob(filename: "whenever.jpg"), create_animals_blob(filename: "wherever.jpg") ]
    end

    assert_difference -> { @user.reload.highlights.count }, -2 do
      @user.update! highlights: nil
    end
  end

  test "attaching existing blobs to a new record for main" do
    AnimalsUser.new(name: "Jason").tap do |user|
      user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
      assert_predicate user, :new_record?
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s

      user.save!
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
    end
  end

  test "attaching an existing blob from a signed ID to a new record for main" do
    AnimalsUser.new(name: "Jason").tap do |user|
      user.highlights.attach create_animals_blob(filename: "funky.jpg").signed_id
      assert_predicate user, :new_record?
      assert_equal "funky.jpg", user.highlights.first.filename.to_s

      user.save!
      assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
    end
  end

  test "attaching new blobs from Hashes to a new record for main" do
    AnimalsUser.new(name: "Jason").tap do |user|
      user.highlights.attach(
        { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpeg" },
        { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg" })

      assert_predicate user, :new_record?
      assert_predicate user.highlights.first, :new_record?
      assert_predicate user.highlights.second, :new_record?
      assert_predicate user.highlights.first.blob, :new_record?
      assert_predicate user.highlights.second.blob, :new_record?
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)

      user.save!
      assert_predicate user.highlights.first, :persisted?
      assert_predicate user.highlights.second, :persisted?
      assert_predicate user.highlights.first.blob, :persisted?
      assert_predicate user.highlights.second.blob, :persisted?
      assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
      assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)
    end
  end

  test "attaching new blobs from uploaded files to a new record for main" do
    AnimalsUser.new(name: "Jason").tap do |user|
      user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
      assert_predicate user, :new_record?
      assert_predicate user.highlights.first, :new_record?
      assert_predicate user.highlights.second, :new_record?
      assert_predicate user.highlights.first.blob, :new_record?
      assert_predicate user.highlights.second.blob, :new_record?
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)

      user.save!
      assert_predicate user.highlights.first, :persisted?
      assert_predicate user.highlights.second, :persisted?
      assert_predicate user.highlights.first.blob, :persisted?
      assert_predicate user.highlights.second.blob, :persisted?
      assert_equal "racecar.jpg", user.reload.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)
    end
  end

  test "creating a record with existing blobs attached for main" do
    user = AnimalsUser.create!(name: "Jason", highlights: [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ])
    assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
    assert_equal "town.jpg", user.reload.highlights.second.filename.to_s
  end

  test "creating a record with an existing blob from signed IDs attached for main" do
    user = AnimalsUser.create!(name: "Jason", highlights: [
      create_animals_blob(filename: "funky.jpg").signed_id, create_animals_blob(filename: "town.jpg").signed_id ])
    assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
    assert_equal "town.jpg", user.reload.highlights.second.filename.to_s
  end

  test "creating a record with new blobs from uploaded files attached for main" do
    AnimalsUser.new(name: "Jason", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ]).tap do |user|
      assert_predicate user, :new_record?
      assert_predicate user.highlights.first, :new_record?
      assert_predicate user.highlights.second, :new_record?
      assert_predicate user.highlights.first.blob, :new_record?
      assert_predicate user.highlights.second.blob, :new_record?
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(user.highlights.second.key)

      user.save!
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
    end
  end

  test "creating a record with an unexpected object attached for main" do
    error = assert_raises(ArgumentError) { AnimalsUser.create!(name: "Jason", highlights: :foo) }
    assert_equal "Could not find or build blob: expected attachable, got :foo", error.message
  end

  test "detaching for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert_predicate @user.highlights, :attached?

      perform_enqueued_jobs do
        @user.highlights.detach
      end

      assert_not @user.highlights.attached?
      assert ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
    end
  end

  test "detaching when record is not persisted for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      user = AnimalsUser.new
      user.highlights.attach blobs
      assert_predicate user.highlights, :attached?

      perform_enqueued_jobs do
        user.highlights.detach
      end

      assert_not user.highlights.attached?
      assert ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
    end
  end

  test "purging for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert_predicate @user.highlights, :attached?

      assert_changes -> { @user.updated_at } do
        @user.highlights.purge
      end
      assert_not @user.highlights.attached?
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
    end
  end

  test "purging attachment with shared blobs for main" do
    [
      create_animals_blob(filename: "funky.jpg"),
      create_animals_blob(filename: "town.jpg"),
      create_animals_blob(filename: "worm.jpg")
    ].tap do |blobs|
      @user.highlights.attach blobs
      assert_predicate @user.highlights, :attached?

      another_user = AnimalsUser.create!(name: "John")
      shared_blobs = [blobs.second, blobs.third]
      another_user.highlights.attach shared_blobs
      assert_predicate another_user.highlights, :attached?

      @user.highlights.purge
      assert_not @user.highlights.attached?

      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.third.id)

      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.third.key)
    end
  end

  test "purging when record is not persisted for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      user = AnimalsUser.new
      user.highlights.attach blobs
      assert_predicate user.highlights, :attached?

      attachments = user.highlights.attachments
      user.highlights.purge

      assert_not user.highlights.attached?
      assert attachments.all?(&:destroyed?)
      blobs.each do |blob|
        assert_not ActiveStorage::AnimalsBlob.exists?(blob.id)
        assert_not ActiveStorage::AnimalsBlob.service.exist?(blob.key)
      end
    end
  end

  test "purging delete changes when record is not persisted for main" do
    user = AnimalsUser.new
    user.highlights = []

    user.highlights.purge

    assert_nil user.attachment_changes["highlights"]
  end

  test "purging later for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert_predicate @user.highlights, :attached?

      perform_enqueued_jobs do
        assert_changes -> { @user.updated_at } do
          @user.highlights.purge_later
        end
      end

      assert_not @user.highlights.attached?
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
    end
  end

  test "purging attachment later with shared blobs for main" do
    [
      create_animals_blob(filename: "funky.jpg"),
      create_animals_blob(filename: "town.jpg"),
      create_animals_blob(filename: "worm.jpg")
    ].tap do |blobs|
      @user.highlights.attach blobs
      assert_predicate @user.highlights, :attached?

      another_user = AnimalsUser.create!(name: "John")
      shared_blobs = [blobs.second, blobs.third]
      another_user.highlights.attach shared_blobs
      assert_predicate another_user.highlights, :attached?

      perform_enqueued_jobs do
        @user.highlights.purge_later
      end

      assert_not @user.highlights.attached?
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert ActiveStorage::AnimalsBlob.exists?(blobs.third.id)

      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
      assert ActiveStorage::AnimalsBlob.service.exist?(blobs.third.key)
    end
  end

  test "purging attachment later when record is not persisted for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      user = AnimalsUser.new
      user.highlights.attach blobs
      assert_predicate user.highlights, :attached?

      perform_enqueued_jobs do
        user.highlights.purge_later
      end

      assert_not user.highlights.attached?
      blobs.each do |blob|
        assert_not ActiveStorage::AnimalsBlob.exists?(blob.id)
        assert_not ActiveStorage::AnimalsBlob.service.exist?(blob.key)
      end
    end
  end

  test "purging dependent attachment later on destroy for main" do
    [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs

      perform_enqueued_jobs do
        @user.destroy!
      end

      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.first.id)
      assert_not ActiveStorage::AnimalsBlob.exists?(blobs.second.id)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::AnimalsBlob.service.exist?(blobs.second.key)
    end
  end

  test "not purging independent attachment on destroy for main" do
    [ create_animals_blob(filename: "funky.mp4"), create_animals_blob(filename: "town.mp4") ].tap do |blobs|
      @user.vlogs.attach blobs

      assert_no_enqueued_jobs do
        @user.destroy!
      end
    end
  end

  test "duped record does not share attachments for main" do
    @user.highlights.attach [ create_animals_blob(filename: "funky.jpg") ]

    assert_not_equal @user.highlights.first, @user.dup.highlights.first
  end

  test "duped record does not share attachment changes for main" do
    @user.highlights.attach [ create_animals_blob(filename: "funky.jpg") ]
    assert_not_predicate @user, :changed_for_autosave?

    @user.dup.highlights.attach [ create_animals_blob(filename: "town.mp4") ]
    assert_not_predicate @user, :changed_for_autosave?
  end

  test "clearing change on reload for main" do
    @user.highlights = [ create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg") ]
    assert_predicate @user.highlights, :attached?

    @user.reload
    assert_not @user.highlights.attached?
  end

  test "overriding attached reader for main" do
    @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s

    begin
      AnimalsUser.class_eval do
        def highlights
          super.reverse
        end
      end

      assert_equal "town.jpg", @user.highlights.first.filename.to_s
      assert_equal "funky.jpg", @user.highlights.second.filename.to_s
    ensure
      AnimalsUser.remove_method :highlights
    end
  end

  test "attaching a new blob from a Hash with a custom service for main" do
    with_animals_service("mirror") do
      @user.highlights.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg"
      @user.vlogs.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpeg"

      assert_instance_of ActiveStorage::Service::MirrorService, @user.highlights.first.service
      assert_instance_of ActiveStorage::Service::DiskService, @user.vlogs.first.service
    end
  end

  test "attaching a new blob from an uploaded file with a custom service for main" do
    with_animals_service("mirror") do
      @user.highlights.attach fixture_file_upload("racecar.jpg")
      @user.vlogs.attach fixture_file_upload("racecar.jpg")

      assert_instance_of ActiveStorage::Service::MirrorService, @user.highlights.first.service
      assert_instance_of ActiveStorage::Service::DiskService, @user.vlogs.first.service
    end
  end

  test "attaching a new blob from an uploaded file with a service defined at runtime for main" do
    extra_attached = Class.new(AnimalsUser) do
      def self.name; superclass.name; end

      has_many_attached :signatures, service: ->(user) { "disk_#{user.mirror_region}" }

      def mirror_region
        :mirror_2
      end
    end

    @user = @user.becomes(extra_attached)

    @user.signatures.attach fixture_file_upload("cropped.pdf")
    assert_equal :disk_mirror_2, @user.signatures.first.service.name
  end

  test "attaching blobs to a persisted, unchanged, and valid record, returns the attachments for main" do
    @user.highlights.attach create_animals_blob(filename: "racecar.jpg")
    return_value = @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_equal @user.highlights, return_value
  end

  test "attaching blobs to a persisted, unchanged, and invalid record, returns nil for main" do
    @user.update_attribute(:name, nil)
    assert_not @user.valid?

    @user.highlights.attach create_animals_blob(filename: "racecar.jpg")
    return_value = @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_nil return_value
  end

  test "attaching blobs to a changed record, returns the attachments for main" do
    @user.name = "Tina"
    @user.highlights.attach create_animals_blob(filename: "racecar.jpg")
    return_value = @user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_equal @user.highlights, return_value
  end

  test "attaching blobs to a non persisted record, returns the attachments for main" do
    user = AnimalsUser.new(name: "John")
    user.highlights.attach create_animals_blob(filename: "racecar.jpg")
    return_value = user.highlights.attach create_animals_blob(filename: "funky.jpg"), create_animals_blob(filename: "town.jpg")
    assert_equal user.highlights, return_value
  end

  test "raises error when global service configuration is missing for main" do
    Rails.configuration.active_storage.stub(:service, nil) do
      error = assert_raises RuntimeError do
        AnimalsUser.class_eval do
          has_many_attached :featured_photos
        end
      end

      assert_match(/Missing Active Storage service name. Specify Active Storage service name for config.active_storage.service in config\/environments\/test.rb/, error.message)
    end
  end

  test "raises error when misconfigured service is passed for main" do
    error = assert_raises ArgumentError do
      AnimalsUser.class_eval do
        has_many_attached :featured_photos, service: :unknown
      end
    end

    assert_match(/Cannot configure service :unknown for AnimalsUser#featured_photos/, error.message)
  end

  test "raises error when misconfigured service is defined at runtime for main" do
    extra_attached = Class.new(AnimalsUser) do
      def self.name; superclass.name; end

      has_many_attached :featured_vlogs, service: ->(*) { :unknown }
    end

    @user = @user.becomes(extra_attached)

    assert_raises match: /Cannot configure service :unknown for .+#featured_vlog/ do
      @user.featured_vlogs.attach fixture_file_upload("video.mp4")
    end
  end

  test "creating variation by variation name for main" do
    assert_no_enqueued_jobs only: ActiveStorage::TransformJob do
      @user.highlights_with_variants.attach fixture_file_upload("racecar.jpg")
    end
    variant = @user.highlights_with_variants.first.variant(:thumb).processed

    image = read_image(variant)
    assert_equal "JPEG", image.type
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "raises error when unknown variant name is used to generate variant for main" do
    @user.highlights_with_variants.attach fixture_file_upload("racecar.jpg")

    error = assert_raises ArgumentError do
      @user.highlights_with_variants.first.variant(:unknown).processed
    end

    assert_match(/Cannot find variant :unknown for AnimalsUser#highlights_with_variants/, error.message)
  end

  test "creating preview by variation name for main" do
    @user.highlights_with_variants.attach fixture_file_upload("report.pdf")
    preview = @user.highlights_with_variants.first.preview(:thumb).processed

    image = read_image(preview.send(:variant))
    assert_equal "PNG", image.type
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "raises error when unknown variant name is used to generate preview for main" do
    @user.highlights_with_variants.attach fixture_file_upload("report.pdf")

    error = assert_raises ArgumentError do
      @user.highlights_with_variants.first.preview(:unknown).processed
    end

    assert_match(/Cannot find variant :unknown for AnimalsUser#highlights_with_variants/, error.message)
  end

  test "creating representation by variation name for main" do
    @user.highlights_with_variants.attach fixture_file_upload("racecar.jpg")
    variant = @user.highlights_with_variants.first.representation(:thumb).processed

    image = read_image(variant)
    assert_equal "JPEG", image.type
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "raises error when unknown variant name is used to generate representation for main" do
    @user.highlights_with_variants.attach fixture_file_upload("racecar.jpg")

    error = assert_raises ArgumentError do
      @user.highlights_with_variants.first.representation(:unknown).processed
    end

    assert_match(/Cannot find variant :unknown for AnimalsUser#highlights_with_variants/, error.message)
  end

  test "transforms variants later for main" do
    blob = create_animals_file_blob(filename: "racecar.jpg")

    assert_enqueued_with job: ActiveStorage::TransformJob, args: [blob, resize_to_limit: [1, 1]] do
      @user.highlights_with_preprocessed.attach blob
    end
  end

  test "transforms variants later conditionally via proc for main" do
    assert_no_enqueued_jobs only: [ ActiveStorage::TransformJob, ActiveStorage::PreviewImageJob ] do
      @user.highlights_with_conditional_preprocessed.attach create_animals_file_blob(filename: "racecar.jpg")
    end

    blob = create_animals_file_blob(filename: "racecar.jpg")
    @user.update(name: "transform via proc")

    assert_enqueued_with job: ActiveStorage::TransformJob, args: [blob, resize_to_limit: [2, 2]] do
      @user.highlights_with_conditional_preprocessed.attach blob
    end
  end

  test "transforms variants later conditionally via method for main" do
    assert_no_enqueued_jobs only: [ ActiveStorage::TransformJob, ActiveStorage::PreviewImageJob ] do
      @user.highlights_with_conditional_preprocessed.attach create_animals_file_blob(filename: "racecar.jpg")
    end

    blob = create_animals_file_blob(filename: "racecar.jpg")
    @user.update(name: "transform via method")

    assert_enqueued_with job: ActiveStorage::TransformJob, args: [blob, resize_to_limit: [3, 3]] do
      assert_no_enqueued_jobs only: ActiveStorage::PreviewImageJob do
        @user.highlights_with_conditional_preprocessed.attach blob
      end
    end
  end

  test "avoids enqueuing transform later and create preview job job when blob is not representable for main" do
    unrepresentable_blob = create_animals_blob(filename: "hello.txt")

    assert_no_enqueued_jobs only: [ ActiveStorage::TransformJob, ActiveStorage::PreviewImageJob ] do
      @user.highlights_with_preprocessed.attach unrepresentable_blob
    end
  end

  test "successfully attaches new blobs and destroys attachments marked for destruction via nested attributes for main" do
    town_blob = create_animals_blob(filename: "town.jpg")
    @user.highlights.attach(town_blob)
    @user.reload

    racecar_blob = fixture_file_upload("racecar.jpg")
    attachment_id = town_blob.attachments.find_by!(record: @user).id
    @user.update(
      highlights: [racecar_blob],
      highlights_attachments_attributes: [{ id: attachment_id, _destroy: true }]
    )

    assert_predicate @user.reload.highlights, :attached?
    assert_equal 1, @user.highlights.count
    assert_equal "racecar.jpg", @user.highlights.blobs.first.filename.to_s
  end
end
