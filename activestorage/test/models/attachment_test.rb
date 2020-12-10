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

    assert blob.reload.analyzed?
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
  end

  test "getting a signed blob ID from an attachment with a custom purpose" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id = @user.avatar.signed_id(purpose: :custom_purpose)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id, purpose: :custom_purpose)
  end

  test "signed blob ID backwards compatibility" do
    blob = create_blob
    @user.avatar.attach(blob)

    signed_id_generated_old_way = ActiveStorage.verifier.generate(@user.avatar.id, purpose: :blob_id)
    assert_equal blob, ActiveStorage::Blob.find_signed!(signed_id_generated_old_way)
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

    def assert_blob_identified_outside_transaction(blob)
      baseline_transaction_depth = ActiveRecord::Base.connection.open_transactions
      max_transaction_depth = -1

      track_transaction_depth = ->(*) do
        max_transaction_depth = [ActiveRecord::Base.connection.open_transactions, max_transaction_depth].max
      end

      blob.stub(:identify_without_saving, track_transaction_depth) do
        yield
      end

      assert_equal 0, (max_transaction_depth - baseline_transaction_depth)
    end
end
