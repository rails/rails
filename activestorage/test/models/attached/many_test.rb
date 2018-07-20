# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ManyAttachedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(name: "Josh")
  end

  teardown { ActiveStorage::Blob.all.each(&:delete) }

  test "attaching existing blobs to an existing record" do
    @user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs from signed IDs to an existing record" do
    @user.highlights.attach create_blob(filename: "funky.jpg").signed_id, create_blob(filename: "town.jpg").signed_id
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from Hashes to an existing record" do
    @user.highlights.attach(
      { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpg" },
      { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg" })

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from uploaded files to an existing record" do
    @user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs from signed IDs to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.highlights.attach create_blob(filename: "funky.jpg").signed_id, create_blob(filename: "town.jpg").signed_id
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from Hashes to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.highlights.attach(
      { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpg" },
      { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpeg" })

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "attaching new blobs from uploaded files to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not @user.highlights.first.persisted?
    assert_not @user.highlights.second.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "racecar.jpg", @user.highlights.reload.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "attaching existing blobs to an existing record one at a time" do
    @user.highlights.attach create_blob(filename: "funky.jpg")
    @user.highlights.attach create_blob(filename: "town.jpg")
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s

    @user.reload
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "updating an existing record to attach existing blobs" do
    @user.update! highlights: [ create_file_blob(filename: "racecar.jpg"), create_file_blob(filename: "video.mp4") ]
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
  end

  test "updating an existing record to attach existing blobs from signed IDs" do
    @user.update! highlights: [ create_blob(filename: "funky.jpg").signed_id, create_blob(filename: "town.jpg").signed_id ]
    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s
  end

  test "successfully updating an existing record to attach new blobs from uploaded files" do
    @user.highlights = [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ]
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.second.key)

    @user.save!
    assert ActiveStorage::Blob.service.exist?(@user.highlights.first.key)
    assert ActiveStorage::Blob.service.exist?(@user.highlights.second.key)
  end

  test "unsuccessfully updating an existing record to attach new blobs from uploaded files" do
    assert_not @user.update(name: "", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ])
    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.second.key)
  end

  test "replacing existing, dependent attachments on an existing record via assign and attach" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |old_blobs|
      @user.highlights.attach old_blobs

      @user.highlights = []
      assert_not @user.highlights.attached?

      perform_enqueued_jobs do
        @user.highlights.attach create_blob(filename: "whenever.jpg"), create_blob(filename: "wherever.jpg")
      end

      assert_equal "whenever.jpg", @user.highlights.first.filename.to_s
      assert_equal "wherever.jpg", @user.highlights.second.filename.to_s
      assert_not ActiveStorage::Blob.exists?(old_blobs.first.id)
      assert_not ActiveStorage::Blob.exists?(old_blobs.second.id)
      assert_not ActiveStorage::Blob.service.exist?(old_blobs.first.key)
      assert_not ActiveStorage::Blob.service.exist?(old_blobs.second.key)
    end
  end

  test "replacing existing, independent attachments on an existing record via assign and attach" do
    @user.vlogs.attach create_blob(filename: "funky.mp4"), create_blob(filename: "town.mp4")

    @user.vlogs = []
    assert_not @user.vlogs.attached?

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.vlogs.attach create_blob(filename: "whenever.mp4"), create_blob(filename: "wherever.mp4")
    end

    assert_equal "whenever.mp4", @user.vlogs.first.filename.to_s
    assert_equal "wherever.mp4", @user.vlogs.second.filename.to_s
  end

  test "successfully updating an existing record to replace existing, dependent attachments" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |old_blobs|
      @user.highlights.attach old_blobs

      perform_enqueued_jobs do
        @user.update! highlights: [ create_blob(filename: "whenever.jpg"), create_blob(filename: "wherever.jpg") ]
      end

      assert_equal "whenever.jpg", @user.highlights.first.filename.to_s
      assert_equal "wherever.jpg", @user.highlights.second.filename.to_s
      assert_not ActiveStorage::Blob.exists?(old_blobs.first.id)
      assert_not ActiveStorage::Blob.exists?(old_blobs.second.id)
      assert_not ActiveStorage::Blob.service.exist?(old_blobs.first.key)
      assert_not ActiveStorage::Blob.service.exist?(old_blobs.second.key)
    end
  end

  test "successfully updating an existing record to replace existing, independent attachments" do
    @user.vlogs.attach create_blob(filename: "funky.mp4"), create_blob(filename: "town.mp4")

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.update! vlogs: [ create_blob(filename: "whenever.mp4"), create_blob(filename: "wherever.mp4") ]
    end

    assert_equal "whenever.mp4", @user.vlogs.first.filename.to_s
    assert_equal "wherever.mp4", @user.vlogs.second.filename.to_s
  end

  test "unsuccessfully updating an existing record to replace existing attachments" do
    @user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg")

    assert_no_enqueued_jobs do
      assert_not @user.update(name: "", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ])
    end

    assert_equal "racecar.jpg", @user.highlights.first.filename.to_s
    assert_equal "video.mp4", @user.highlights.second.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.first.key)
    assert_not ActiveStorage::Blob.service.exist?(@user.highlights.second.key)
  end

  test "updating an existing record to attach one new blob and one previously-attached blob" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs.first

      perform_enqueued_jobs do
        assert_no_changes -> { @user.highlights_attachments.first.id } do
          @user.update! highlights: blobs
        end
      end

      assert_equal "funky.jpg", @user.highlights.first.filename.to_s
      assert_equal "town.jpg", @user.highlights.second.filename.to_s
      assert ActiveStorage::Blob.service.exist?(@user.highlights.first.key)
    end
  end

  test "updating an existing record to remove dependent attachments" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs

      assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blobs.first ] do
        assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blobs.second ] do
          @user.update! highlights: []
        end
      end

      assert_not @user.highlights.attached?
    end
  end

  test "updating an existing record to remove independent attachments" do
    [ create_blob(filename: "funky.mp4"), create_blob(filename: "town.mp4") ].tap do |blobs|
      @user.vlogs.attach blobs

      assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
        @user.update! vlogs: []
      end

      assert_not @user.vlogs.attached?
    end
  end

  test "analyzing a new blob from an uploaded file after attaching it to an existing record" do
    perform_enqueued_jobs do
      @user.highlights.attach fixture_file_upload("racecar.jpg")
    end

    assert @user.highlights.reload.first.analyzed?
    assert_equal 4104, @user.highlights.first.metadata[:width]
    assert_equal 2736, @user.highlights.first.metadata[:height]
  end

  test "analyzing a new blob from an uploaded file after attaching it to an existing record via update" do
    perform_enqueued_jobs do
      @user.update! highlights: [ fixture_file_upload("racecar.jpg") ]
    end

    assert @user.highlights.reload.first.analyzed?
    assert_equal 4104, @user.highlights.first.metadata[:width]
    assert_equal 2736, @user.highlights.first.metadata[:height]
  end

  test "analyzing a directly-uploaded blob after attaching it to an existing record" do
    perform_enqueued_jobs do
      @user.highlights.attach directly_upload_file_blob(filename: "racecar.jpg")
    end

    assert @user.highlights.reload.first.analyzed?
    assert_equal 4104, @user.highlights.first.metadata[:width]
    assert_equal 2736, @user.highlights.first.metadata[:height]
  end

  test "analyzing a directly-uploaded blob after attaching it to an existing record via update" do
    perform_enqueued_jobs do
      @user.update! highlights: [ directly_upload_file_blob(filename: "racecar.jpg") ]
    end

    assert @user.highlights.reload.first.analyzed?
    assert_equal 4104, @user.highlights.first.metadata[:width]
    assert_equal 2736, @user.highlights.first.metadata[:height]
  end

  test "attaching existing blobs to a new record" do
    User.new(name: "Jason").tap do |user|
      user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg")
      assert user.new_record?
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s

      user.save!
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
    end
  end

  test "attaching an existing blob from a signed ID to a new record" do
    User.new(name: "Jason").tap do |user|
      user.avatar.attach create_blob(filename: "funky.jpg").signed_id
      assert user.new_record?
      assert_equal "funky.jpg", user.avatar.filename.to_s

      user.save!
      assert_equal "funky.jpg", user.reload.avatar.filename.to_s
    end
  end

  test "attaching new blobs from Hashes to a new record" do
    User.new(name: "Jason").tap do |user|
      user.highlights.attach(
        { io: StringIO.new("STUFF"), filename: "funky.jpg", content_type: "image/jpg" },
        { io: StringIO.new("THINGS"), filename: "town.jpg", content_type: "image/jpg" })

      assert user.new_record?
      assert user.highlights.first.new_record?
      assert user.highlights.second.new_record?
      assert user.highlights.first.blob.new_record?
      assert user.highlights.second.blob.new_record?
      assert_equal "funky.jpg", user.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.second.key)

      user.save!
      assert user.highlights.first.persisted?
      assert user.highlights.second.persisted?
      assert user.highlights.first.blob.persisted?
      assert user.highlights.second.blob.persisted?
      assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
      assert_equal "town.jpg", user.highlights.second.filename.to_s
      assert ActiveStorage::Blob.service.exist?(user.highlights.first.key)
      assert ActiveStorage::Blob.service.exist?(user.highlights.second.key)
    end
  end

  test "attaching new blobs from uploaded files to a new record" do
    User.new(name: "Jason").tap do |user|
      user.highlights.attach fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4")
      assert user.new_record?
      assert user.highlights.first.new_record?
      assert user.highlights.second.new_record?
      assert user.highlights.first.blob.new_record?
      assert user.highlights.second.blob.new_record?
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.second.key)

      user.save!
      assert user.highlights.first.persisted?
      assert user.highlights.second.persisted?
      assert user.highlights.first.blob.persisted?
      assert user.highlights.second.blob.persisted?
      assert_equal "racecar.jpg", user.reload.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert ActiveStorage::Blob.service.exist?(user.highlights.first.key)
      assert ActiveStorage::Blob.service.exist?(user.highlights.second.key)
    end
  end

  test "creating a record with existing blobs attached" do
    user = User.create!(name: "Jason", highlights: [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ])
    assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
    assert_equal "town.jpg", user.reload.highlights.second.filename.to_s
  end

  test "creating a record with an existing blob from signed IDs attached" do
    user = User.create!(name: "Jason", highlights: [
      create_blob(filename: "funky.jpg").signed_id, create_blob(filename: "town.jpg").signed_id ])
    assert_equal "funky.jpg", user.reload.highlights.first.filename.to_s
    assert_equal "town.jpg", user.reload.highlights.second.filename.to_s
  end

  test "creating a record with new blobs from uploaded files attached" do
    User.new(name: "Jason", highlights: [ fixture_file_upload("racecar.jpg"), fixture_file_upload("video.mp4") ]).tap do |user|
      assert user.new_record?
      assert user.highlights.first.new_record?
      assert user.highlights.second.new_record?
      assert user.highlights.first.blob.new_record?
      assert user.highlights.second.blob.new_record?
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.first.key)
      assert_not ActiveStorage::Blob.service.exist?(user.highlights.second.key)

      user.save!
      assert_equal "racecar.jpg", user.highlights.first.filename.to_s
      assert_equal "video.mp4", user.highlights.second.filename.to_s
    end
  end

  test "creating a record with an unexpected object attached" do
    error = assert_raises(ArgumentError) { User.create!(name: "Jason", highlights: :foo) }
    assert_equal "Could not find or build blob: expected attachable, got :foo", error.message
  end

  test "analyzing a new blob from an uploaded file after attaching it to a new record" do
    perform_enqueued_jobs do
      user = User.create!(name: "Jason", highlights: [ fixture_file_upload("racecar.jpg") ])
      assert user.highlights.reload.first.analyzed?
      assert_equal 4104, user.highlights.first.metadata[:width]
      assert_equal 2736, user.highlights.first.metadata[:height]
    end
  end

  test "analyzing a directly-uploaded blob after attaching it to a new record" do
    perform_enqueued_jobs do
      user = User.create!(name: "Jason", highlights: [ directly_upload_file_blob(filename: "racecar.jpg") ])
      assert user.highlights.reload.first.analyzed?
      assert_equal 4104, user.highlights.first.metadata[:width]
      assert_equal 2736, user.highlights.first.metadata[:height]
    end
  end

  test "detaching" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert @user.highlights.attached?

      perform_enqueued_jobs do
        @user.highlights.detach
      end

      assert_not @user.highlights.attached?
      assert ActiveStorage::Blob.exists?(blobs.first.id)
      assert ActiveStorage::Blob.exists?(blobs.second.id)
      assert ActiveStorage::Blob.service.exist?(blobs.first.key)
      assert ActiveStorage::Blob.service.exist?(blobs.second.key)
    end
  end

  test "purging" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert @user.highlights.attached?

      @user.highlights.purge
      assert_not @user.highlights.attached?
      assert_not ActiveStorage::Blob.exists?(blobs.first.id)
      assert_not ActiveStorage::Blob.exists?(blobs.second.id)
      assert_not ActiveStorage::Blob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::Blob.service.exist?(blobs.second.key)
    end
  end

  test "purging later" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs
      assert @user.highlights.attached?

      perform_enqueued_jobs do
        @user.highlights.purge_later
      end

      assert_not @user.highlights.attached?
      assert_not ActiveStorage::Blob.exists?(blobs.first.id)
      assert_not ActiveStorage::Blob.exists?(blobs.second.id)
      assert_not ActiveStorage::Blob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::Blob.service.exist?(blobs.second.key)
    end
  end

  test "purging dependent attachment later on destroy" do
    [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ].tap do |blobs|
      @user.highlights.attach blobs

      perform_enqueued_jobs do
        @user.destroy!
      end

      assert_not ActiveStorage::Blob.exists?(blobs.first.id)
      assert_not ActiveStorage::Blob.exists?(blobs.second.id)
      assert_not ActiveStorage::Blob.service.exist?(blobs.first.key)
      assert_not ActiveStorage::Blob.service.exist?(blobs.second.key)
    end
  end

  test "not purging independent attachment on destroy" do
    [ create_blob(filename: "funky.mp4"), create_blob(filename: "town.mp4") ].tap do |blobs|
      @user.vlogs.attach blobs

      assert_no_enqueued_jobs do
        @user.destroy!
      end
    end
  end

  test "clearing change on reload" do
    @user.highlights = [ create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg") ]
    assert @user.highlights.attached?

    @user.reload
    assert_not @user.highlights.attached?
  end

  test "overriding attached reader" do
    @user.highlights.attach create_blob(filename: "funky.jpg"), create_blob(filename: "town.jpg")

    assert_equal "funky.jpg", @user.highlights.first.filename.to_s
    assert_equal "town.jpg", @user.highlights.second.filename.to_s

    begin
      User.class_eval do
        def highlights
          super.reverse
        end
      end

      assert_equal "town.jpg", @user.highlights.first.filename.to_s
      assert_equal "funky.jpg", @user.highlights.second.filename.to_s
    ensure
      User.send(:remove_method, :highlights)
    end
  end
end
