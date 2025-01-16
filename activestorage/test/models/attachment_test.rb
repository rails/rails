# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_support/testing/method_call_assertions"

class ActiveStorage::AttachmentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(name: "Josh")
  end

  teardown { ActiveStorage::Blob.all.each(&:delete) }

  test "analyzing a directly-uploaded blob after attaching it" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")
    assert_not blob.analyzed?

    perform_enqueued_jobs do
      @user.highlights.attach(blob)
    end

    assert_predicate blob.reload, :analyzed?
    assert_equal 4104, blob.metadata[:width]
    assert_equal 2736, blob.metadata[:height]
  end

  test "attaching a un-analyzable blob" do
    blob = create_blob(filename: "blank.txt")

    assert_not_predicate blob, :analyzed?

    assert_no_enqueued_jobs do
      @user.highlights.attach(blob)
    end

    assert_predicate blob.reload, :analyzed?
  end

  test "attaching a blob doesn't touch the record" do
    data = "Something else entirely!"
    io = StringIO.new(data)
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: ActiveStorage.checksum_implementation.base64digest(data)
    blob.upload(io)

    user = User.create!(
      name: "Roger",
      avatar: blob.signed_id,
      record_callbacks: true,
    )

    assert_equal(1, user.callback_counter)
  end

  test "attaching a record doesn't reset the previously_new_record flag" do
    @user.highlights.attach(io: ::StringIO.new("dummy"), filename: "dummy.txt")

    assert(@user.notification_sent)
  end

  test "mirroring a directly-uploaded blob after attaching it" do
    with_service("mirror") do
      blob = directly_upload_file_blob
      assert_not ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)

      perform_enqueued_jobs do
        @user.highlights.attach(blob)
      end

      assert ActiveStorage::Blob.service.mirrors.second.exist?(blob.key)
    end
  end

  test "directly-uploaded blob identification for one attached occurs before validation" do
    blob = directly_upload_file_blob(filename: "racecar.jpg", content_type: "application/octet-stream")

    assert_blob_identified_before_owner_validated(@user, blob, "image/jpeg") do
      @user.avatar.attach(blob)
    end
  end

  test "directly-uploaded blob identification for many attached occurs before validation" do
    blob = directly_upload_file_blob(filename: "racecar.jpg", content_type: "application/octet-stream")

    assert_blob_identified_before_owner_validated(@user, blob, "image/jpeg") do
      @user.highlights.attach(blob)
    end
  end

  test "directly-uploaded blob identification for one attached occurs outside transaction" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")

    assert_blob_identified_outside_transaction(blob) do
      @user.avatar.attach(blob)
    end
  end

  test "directly-uploaded blob identification for many attached occurs outside transaction" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")

    assert_blob_identified_outside_transaction(blob) do
      @user.highlights.attach(blob)
    end
  end

  test "getting a signed blob ID from an attachment" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id)
    assert_equal blob, ActiveStorage::Blob.find_signed(signed_id)
  end

  test "getting a signed blob ID from an attachment with a custom purpose" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(purpose: :custom_purpose)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id, purpose: :custom_purpose)
  end

  test "getting a signed blob ID from an attachment with a expires_in" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(expires_in: 1.minute)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id)
  end

  test "fail to find blob within expiration duration" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(expires_in: 1.minute)
    travel 2.minutes
    assert_nil ActiveStorage::Blob.find_signed(signed_id)
  end

  test "getting a signed blob ID from an attachment with a expires_at" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(expires_at: 1.minute.from_now)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id)
  end

  test "fail to find blob within expiration time" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(expires_at: 1.minute.from_now)
    travel 2.minutes
    assert_nil ActiveStorage::Blob.find_signed(signed_id)
  end

  test "signed blob ID backwards compatibility" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id_generated_old_way = ActiveStorage.verifier.generate(@user.avatar.blob.id, purpose: :blob_id)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id_generated_old_way)
  end

  test "attaching with strict_loading and getting a signed blob ID from an attachment" do
    blob = create_blob
    @user.strict_loading!(true)
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id
    assert_equal blob, ActiveStorage::Blob.find_signed(signed_id)
  end

  test "can destroy attachment without existing relation" do
    blob = create_blob
    @user.highlights.attach(blob)
    attachment = @user.highlights.find_by(blob_id: blob.id)
    attachment.update_attribute(:name, "old_highlights")
    assert_nothing_raised { attachment.destroy }
  end

  test "can create an attachment with the record having no attachment reflections" do
    assert_nothing_raised { ActiveStorage::Attachment.create!(name: "whatever", record: @user, blob: create_blob) }
  end

  private
    def assert_blob_identified_before_owner_validated(owner, blob, content_type)
      validated_content_type = nil

      owner.class.validate do
        validated_content_type ||= blob.content_type
      end

      yield

      assert_equal content_type, validated_content_type
      assert_equal content_type, blob.reload.content_type
    end

    def assert_blob_identified_outside_transaction(blob, &block)
      baseline_transaction_depth = ActiveRecord::Base.lease_connection.open_transactions
      max_transaction_depth = -1

      track_transaction_depth = ->(*) do
        max_transaction_depth = [ActiveRecord::Base.lease_connection.open_transactions, max_transaction_depth].max
      end

      blob.stub(:identify_without_saving, track_transaction_depth, &block)

      assert_equal 0, (max_transaction_depth - baseline_transaction_depth)
    end
end
