# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::OneAttachedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(name: "Josh")
  end

  teardown do
    ActiveStorage::Blob.all.each(&:delete)
  end

  test "attaching an existing blob to an existing record" do
    @user.avatar.attach create_blob(filename: "funky.jpg")
    assert_equal "funky.jpg", @user.avatar.filename.to_s

    assert_not_nil @user.avatar_attachment
    assert_not_nil @user.avatar_blob
  end

  test "attaching an existing blob from a signed ID to an existing record" do
    @user.avatar.attach create_blob(filename: "funky.jpg").signed_id
    assert_equal "funky.jpg", @user.avatar.filename.to_s
  end

  test "attaching a new blob from a Hash to an existing record" do
    @user.avatar.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg"
    assert_equal "town.jpg", @user.avatar.filename.to_s
  end

  test "attaching a new blob from an uploaded file to an existing record" do
    @user.avatar.attach fixture_file_upload("racecar.jpg")
    assert_equal "racecar.jpg", @user.avatar.filename.to_s
  end

  test "attaching an existing blob to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.avatar.attach create_blob(filename: "funky.jpg")
    assert_equal "funky.jpg", @user.avatar.filename.to_s
    assert_not @user.avatar.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.reload.avatar.filename.to_s
  end

  test "attaching an existing blob from a signed ID to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.avatar.attach create_blob(filename: "funky.jpg").signed_id
    assert_equal "funky.jpg", @user.avatar.filename.to_s
    assert_not @user.avatar.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "funky.jpg", @user.reload.avatar.filename.to_s
  end

  test "attaching a new blob from a Hash to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.avatar.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg"
    assert_equal "town.jpg", @user.avatar.filename.to_s
    assert_not @user.avatar.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "town.jpg", @user.reload.avatar.filename.to_s
  end

  test "attaching a new blob from an uploaded file to an existing, changed record" do
    @user.name = "Tina"
    assert @user.changed?

    @user.avatar.attach fixture_file_upload("racecar.jpg")
    assert_equal "racecar.jpg", @user.avatar.filename.to_s
    assert_not @user.avatar.persisted?
    assert @user.will_save_change_to_name?

    @user.save!
    assert_equal "racecar.jpg", @user.reload.avatar.filename.to_s
  end

  test "updating an existing record to attach an existing blob" do
    @user.update! avatar: create_blob(filename: "funky.jpg")
    assert_equal "funky.jpg", @user.avatar.filename.to_s
  end

  test "updating an existing record to attach an existing blob from a signed ID" do
    @user.update! avatar: create_blob(filename: "funky.jpg").signed_id
    assert_equal "funky.jpg", @user.avatar.filename.to_s
  end

  test "successfully updating an existing record to attach a new blob from an uploaded file" do
    @user.avatar = fixture_file_upload("racecar.jpg")
    assert_equal "racecar.jpg", @user.avatar.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.avatar.key)

    @user.save!
    assert ActiveStorage::Blob.service.exist?(@user.avatar.key)
  end

  test "unsuccessfully updating an existing record to attach a new blob from an uploaded file" do
    assert_not @user.update(name: "", avatar: fixture_file_upload("racecar.jpg"))
    assert_equal "racecar.jpg", @user.avatar.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.avatar.key)
  end

  test "successfully replacing an existing, dependent attachment on an existing record" do
    create_blob(filename: "funky.jpg").tap do |old_blob|
      @user.avatar.attach old_blob

      perform_enqueued_jobs do
        @user.avatar.attach create_blob(filename: "town.jpg")
      end

      assert_equal "town.jpg", @user.avatar.filename.to_s
      assert_not ActiveStorage::Blob.exists?(old_blob.id)
      assert_not ActiveStorage::Blob.service.exist?(old_blob.key)
    end
  end

  test "replacing an existing, independent attachment on an existing record" do
    @user.cover_photo.attach create_blob(filename: "funky.jpg")

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.cover_photo.attach create_blob(filename: "town.jpg")
    end

    assert_equal "town.jpg", @user.cover_photo.filename.to_s
  end

  test "replacing an attached blob on an existing record with itself" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob

      assert_no_changes -> { @user.reload.avatar_attachment.id } do
        assert_no_enqueued_jobs do
          @user.avatar.attach blob
        end
      end

      assert_equal "funky.jpg", @user.avatar.filename.to_s
      assert ActiveStorage::Blob.service.exist?(@user.avatar.key)
    end
  end

  test "successfully updating an existing record to replace an existing, dependent attachment" do
    create_blob(filename: "funky.jpg").tap do |old_blob|
      @user.avatar.attach old_blob

      perform_enqueued_jobs do
        @user.update! avatar: create_blob(filename: "town.jpg")
      end

      assert_equal "town.jpg", @user.avatar.filename.to_s
      assert_not ActiveStorage::Blob.exists?(old_blob.id)
      assert_not ActiveStorage::Blob.service.exist?(old_blob.key)
    end
  end

  test "successfully updating an existing record to replace an existing, independent attachment" do
    @user.cover_photo.attach create_blob(filename: "funky.jpg")

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      @user.update! cover_photo: create_blob(filename: "town.jpg")
    end

    assert_equal "town.jpg", @user.cover_photo.filename.to_s
  end

  test "unsuccessfully updating an existing record to replace an existing attachment" do
    @user.avatar.attach create_blob(filename: "funky.jpg")

    assert_no_enqueued_jobs do
      assert_not @user.update(name: "", avatar: fixture_file_upload("racecar.jpg"))
    end

    assert_equal "racecar.jpg", @user.avatar.filename.to_s
    assert_not ActiveStorage::Blob.service.exist?(@user.avatar.key)
  end

  test "updating an existing record to replace an attached blob with itself" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob

      assert_no_enqueued_jobs do
        assert_no_changes -> { @user.reload.avatar_attachment.id } do
          @user.update! avatar: blob
        end
      end
    end
  end

  test "removing a dependent attachment from an existing record" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob

      assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blob ] do
        @user.avatar.attach nil
      end

      assert_not @user.avatar.attached?
    end
  end

  test "removing an independent attachment from an existing record" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.cover_photo.attach blob

      assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
        @user.cover_photo.attach nil
      end

      assert_not @user.cover_photo.attached?
    end
  end

  test "updating an existing record to remove a dependent attachment" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob

      assert_enqueued_with job: ActiveStorage::PurgeJob, args: [ blob ] do
        @user.update! avatar: nil
      end

      assert_not @user.avatar.attached?
    end
  end

  test "updating an existing record to remove an independent attachment" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.cover_photo.attach blob

      assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
        @user.update! cover_photo: nil
      end

      assert_not @user.cover_photo.attached?
    end
  end

  test "analyzing a new blob from an uploaded file after attaching it to an existing record" do
    perform_enqueued_jobs do
      @user.avatar.attach fixture_file_upload("racecar.jpg")
    end

    assert @user.avatar.reload.analyzed?
    assert_equal 4104, @user.avatar.metadata[:width]
    assert_equal 2736, @user.avatar.metadata[:height]
  end

  test "analyzing a new blob from an uploaded file after attaching it to an existing record via update" do
    perform_enqueued_jobs do
      @user.update! avatar: fixture_file_upload("racecar.jpg")
    end

    assert @user.avatar.reload.analyzed?
    assert_equal 4104, @user.avatar.metadata[:width]
    assert_equal 2736, @user.avatar.metadata[:height]
  end

  test "analyzing a directly-uploaded blob after attaching it to an existing record" do
    perform_enqueued_jobs do
      @user.avatar.attach directly_upload_file_blob(filename: "racecar.jpg")
    end

    assert @user.avatar.reload.analyzed?
    assert_equal 4104, @user.avatar.metadata[:width]
    assert_equal 2736, @user.avatar.metadata[:height]
  end

  test "analyzing a directly-uploaded blob after attaching it to an existing record via updates" do
    perform_enqueued_jobs do
      @user.update! avatar: directly_upload_file_blob(filename: "racecar.jpg")
    end

    assert @user.avatar.reload.analyzed?
    assert_equal 4104, @user.avatar.metadata[:width]
    assert_equal 2736, @user.avatar.metadata[:height]
  end

  test "creating an attachment as part of an autosave association through nested attributes" do
    group = Group.create!(users_attributes: [{ name: "John", avatar: { io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg" } }])
    group.save!
    new_user = User.find_by(name: "John")
    assert new_user.avatar.attached?
  end

  test "updating an attachment as part of an autosave association" do
    group = Group.create!(users: [@user])
    @user.avatar = fixture_file_upload("racecar.jpg")
    group.save!
    @user.reload
    assert @user.avatar.attached?
  end

  test "attaching an existing blob to a new record" do
    User.new(name: "Jason").tap do |user|
      user.avatar.attach create_blob(filename: "funky.jpg")
      assert user.new_record?
      assert_equal "funky.jpg", user.avatar.filename.to_s

      user.save!
      assert_equal "funky.jpg", user.reload.avatar.filename.to_s
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

  test "attaching a new blob from a Hash to a new record" do
    User.new(name: "Jason").tap do |user|
      user.avatar.attach io: StringIO.new("STUFF"), filename: "town.jpg", content_type: "image/jpg"
      assert user.new_record?
      assert user.avatar.attachment.new_record?
      assert user.avatar.blob.new_record?
      assert_equal "town.jpg", user.avatar.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.avatar.key)

      user.save!
      assert user.avatar.attachment.persisted?
      assert user.avatar.blob.persisted?
      assert_equal "town.jpg", user.reload.avatar.filename.to_s
      assert ActiveStorage::Blob.service.exist?(user.avatar.key)
    end
  end

  test "attaching a new blob from an uploaded file to a new record" do
    User.new(name: "Jason").tap do |user|
      user.avatar.attach fixture_file_upload("racecar.jpg")
      assert user.new_record?
      assert user.avatar.attachment.new_record?
      assert user.avatar.blob.new_record?
      assert_equal "racecar.jpg", user.avatar.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.avatar.key)

      user.save!
      assert user.avatar.attachment.persisted?
      assert user.avatar.blob.persisted?
      assert_equal "racecar.jpg", user.reload.avatar.filename.to_s
      assert ActiveStorage::Blob.service.exist?(user.avatar.key)
    end
  end

  test "creating a record with an existing blob attached" do
    user = User.create!(name: "Jason", avatar: create_blob(filename: "funky.jpg"))
    assert_equal "funky.jpg", user.reload.avatar.filename.to_s
  end

  test "creating a record with an existing blob from a signed ID attached" do
    user = User.create!(name: "Jason", avatar: create_blob(filename: "funky.jpg").signed_id)
    assert_equal "funky.jpg", user.reload.avatar.filename.to_s
  end

  test "creating a record with a new blob from an uploaded file attached" do
    User.new(name: "Jason", avatar: fixture_file_upload("racecar.jpg")).tap do |user|
      assert user.new_record?
      assert user.avatar.attachment.new_record?
      assert user.avatar.blob.new_record?
      assert_equal "racecar.jpg", user.avatar.filename.to_s
      assert_not ActiveStorage::Blob.service.exist?(user.avatar.key)

      user.save!
      assert_equal "racecar.jpg", user.reload.avatar.filename.to_s
    end
  end

  test "creating a record with an unexpected object attached" do
    error = assert_raises(ArgumentError) { User.create!(name: "Jason", avatar: :foo) }
    assert_equal "Could not find or build blob: expected attachable, got :foo", error.message
  end

  test "analyzing a new blob from an uploaded file after attaching it to a new record" do
    perform_enqueued_jobs do
      user = User.create!(name: "Jason", avatar: fixture_file_upload("racecar.jpg"))
      assert user.avatar.reload.analyzed?
      assert_equal 4104, user.avatar.metadata[:width]
      assert_equal 2736, user.avatar.metadata[:height]
    end
  end

  test "analyzing a directly-uploaded blob after attaching it to a new record" do
    perform_enqueued_jobs do
      user = User.create!(name: "Jason", avatar: directly_upload_file_blob(filename: "racecar.jpg"))
      assert user.avatar.reload.analyzed?
      assert_equal 4104, user.avatar.metadata[:width]
      assert_equal 2736, user.avatar.metadata[:height]
    end
  end

  test "detaching" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob
      assert @user.avatar.attached?

      perform_enqueued_jobs do
        @user.avatar.detach
      end

      assert_not @user.avatar.attached?
      assert ActiveStorage::Blob.exists?(blob.id)
      assert ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purging" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob
      assert @user.avatar.attached?

      @user.avatar.purge
      assert_not @user.avatar.attached?
      assert_not ActiveStorage::Blob.exists?(blob.id)
      assert_not ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purging an attachment with a shared blob" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob
      assert @user.avatar.attached?

      another_user = User.create!(name: "John")
      another_user.avatar.attach blob
      assert another_user.avatar.attached?

      @user.avatar.purge
      assert_not @user.avatar.attached?
      assert ActiveStorage::Blob.exists?(blob.id)
      assert ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purging later" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob
      assert @user.avatar.attached?

      perform_enqueued_jobs do
        @user.avatar.purge_later
      end

      assert_not @user.avatar.attached?
      assert_not ActiveStorage::Blob.exists?(blob.id)
      assert_not ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purging an attachment later with shared blob" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob
      assert @user.avatar.attached?

      another_user = User.create!(name: "John")
      another_user.avatar.attach blob
      assert another_user.avatar.attached?

      perform_enqueued_jobs do
        @user.avatar.purge_later
      end

      assert_not @user.avatar.attached?
      assert ActiveStorage::Blob.exists?(blob.id)
      assert ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "purging dependent attachment later on destroy" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.avatar.attach blob

      perform_enqueued_jobs do
        @user.destroy!
      end

      assert_not ActiveStorage::Blob.exists?(blob.id)
      assert_not ActiveStorage::Blob.service.exist?(blob.key)
    end
  end

  test "not purging independent attachment on destroy" do
    create_blob(filename: "funky.jpg").tap do |blob|
      @user.cover_photo.attach blob

      assert_no_enqueued_jobs do
        @user.destroy!
      end
    end
  end

  test "duped record does not share attachments" do
    @user.avatar.attach create_blob(filename: "funky.jpg")

    assert_not_equal @user.avatar.attachment, @user.dup.avatar.attachment
  end

  test "duped record does not share attachment changes" do
    @user.avatar.attach create_blob(filename: "funky.jpg")
    assert_not_predicate @user, :changed_for_autosave?

    @user.dup.avatar.attach create_blob(filename: "town.jpg")
    assert_not_predicate @user, :changed_for_autosave?
  end

  test "clearing change on reload" do
    @user.avatar = create_blob(filename: "funky.jpg")
    assert @user.avatar.attached?

    @user.reload
    assert_not @user.avatar.attached?
  end

  test "overriding attached reader" do
    @user.avatar.attach create_blob(filename: "funky.jpg")

    assert_equal "funky.jpg", @user.avatar.filename.to_s

    begin
      User.class_eval do
        def avatar
          super.filename.to_s.reverse
        end
      end

      assert_equal "gpj.yknuf", @user.avatar
    ensure
      User.remove_method :avatar
    end
  end
end
