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
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: OpenSSL::Digest::MD5.base64digest(data)
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

  test "create immediate variants on attach" do
    blob = create_file_blob

    assert_changes -> { @user.avatar_with_immediate_variants.variant(:immediate_thumb)&.processed? }, from: nil, to: true do
      @user.avatar_with_immediate_variants.attach blob
    end
  end

  test "create immediate variants from local file without downloading" do
    # When attaching a fresh file (not an existing blob), immediate variants
    # should be processed from the local io without downloading from the service.
    download_called = false
    original_download = ActiveStorage::Blob.service.method(:download)

    ActiveStorage::Blob.service.define_singleton_method(:download) do |key, &block|
      download_called = true
      original_download.call(key, &block)
    end

    @user.avatar_with_immediate_variants.attach(
      io: file_fixture("racecar.jpg").open,
      filename: "racecar.jpg",
      content_type: "image/jpeg"
    )

    assert @user.avatar_with_immediate_variants.variant(:immediate_thumb).processed?,
      "Immediate variant should be processed"
    assert_not download_called,
      "Download should not be called when processing immediate variants from local file"
  ensure
    # Restore the original method
    ActiveStorage::Blob.service.singleton_class.remove_method(:download) if ActiveStorage::Blob.service.respond_to?(:download, true)
  end

  test "analyze from local file without downloading for immediate variant attachments" do
    # Attachments with process: :immediately variants analyze from local io
    # without downloading from the service.
    download_called = false
    original_download = ActiveStorage::Blob.service.method(:download)

    ActiveStorage::Blob.service.define_singleton_method(:download) do |key, &block|
      download_called = true
      original_download.call(key, &block)
    end

    @user.avatar_with_immediate_variants.attach(
      io: file_fixture("racecar.jpg").open,
      filename: "racecar.jpg",
      content_type: "image/jpeg"
    )

    assert @user.avatar_with_immediate_variants.blob.analyzed?, "Blob should be analyzed"
    assert_equal 4104, @user.avatar_with_immediate_variants.blob.metadata[:width]
    assert_equal 2736, @user.avatar_with_immediate_variants.blob.metadata[:height]
    assert_not download_called,
      "Download should not be called when analyzing from local file"
  ensure
    ActiveStorage::Blob.service.singleton_class.remove_method(:download) if ActiveStorage::Blob.service.respond_to?(:download, true)
  end

  test "enqueues create variants job to delay transformations after attach" do
    blob = create_file_blob
    assert_create_variants_job blob:, variants: [{ resize_to_limit: [2, 2] }] do
      @user.avatar_with_later_variants.attach blob
    end
  end

  test "avoids enqueuing create variants job when lazy" do
    blob = create_file_blob

    assert_no_enqueued_jobs only: ActiveStorage::CreateVariantsJob  do
      @user.avatar_with_lazy_variants.attach blob
    end
  end

  test "avoids enqueuing create variants job when blob is not representable" do
    unrepresentable_blob = create_blob(filename: "hello.txt")

    assert_no_enqueued_jobs only: ActiveStorage::CreateVariantsJob  do
      @user.avatar_with_later_variants.attach unrepresentable_blob
    end
  end

  test "avoids enqueuing create variants job if there aren't any variants" do
    blob = create_file_blob

    assert_no_enqueued_jobs only: ActiveStorage::CreateVariantsJob do
      @user.resume.attach blob
    end
  end

  test "analysis metadata available before validation for immediate variant attachments" do
    # Attachments with process: :immediately variants eagerly analyze,
    # making metadata available during validation.
    validated_width = nil
    validated_height = nil

    User.validate do
      if avatar_with_immediate_variants.attached? && avatar_with_immediate_variants.blob
        validated_width = avatar_with_immediate_variants.blob.metadata[:width]
        validated_height = avatar_with_immediate_variants.blob.metadata[:height]
      end
    end

    user = User.create! \
      name: "Analysis Test",
      avatar_with_immediate_variants: { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }

    # Analysis metadata was available during validation
    assert_equal 4104, validated_width
    assert_equal 2736, validated_height

    # And persisted correctly
    assert_equal 4104, user.avatar_with_immediate_variants.blob.metadata[:width]
    assert_equal 2736, user.avatar_with_immediate_variants.blob.metadata[:height]
  ensure
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "analysis metadata available before validation for has_many_attached with immediate variants" do
    validated_widths = []

    User.validate do
      highlights_with_immediate_variants.each do |highlight|
        validated_widths << highlight.blob.metadata[:width] if highlight.blob
      end
    end

    user = User.create! \
      name: "Analysis Test",
      highlights_with_immediate_variants: [
        { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }
      ]

    assert_equal [4104], validated_widths
    assert_equal 4104, user.highlights_with_immediate_variants.first.blob.metadata[:width]
  ensure
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "analyze: :immediately analyzes during validation" do
    validated_width = nil

    User.validate do
      if avatar_with_immediate_analysis.attached? && avatar_with_immediate_analysis.blob
        validated_width = avatar_with_immediate_analysis.blob.metadata[:width]
      end
    end

    user = User.create! \
      name: "Analysis Test",
      avatar_with_immediate_analysis: { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }

    assert_equal 4104, validated_width
    assert_equal 4104, user.avatar_with_immediate_analysis.blob.metadata[:width]
  ensure
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "analyze: :later skips analysis during validation but analyzes after upload" do
    validated_width = nil

    User.validate do
      if avatar_with_later_analysis.attached? && avatar_with_later_analysis.blob
        validated_width = avatar_with_later_analysis.blob.metadata[:width]
      end
    end

    user = User.create! \
      name: "Analysis Test",
      avatar_with_later_analysis: { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }

    # Not analyzed during validation
    assert_nil validated_width

    # Analyzed after upload (from local io, no job needed)
    assert_equal 4104, user.avatar_with_later_analysis.blob.metadata[:width]
  ensure
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "analyze: :lazily skips analysis during validation" do
    validated_width = nil

    User.validate do
      if avatar_with_lazy_analysis.attached? && avatar_with_lazy_analysis.blob
        validated_width = avatar_with_lazy_analysis.blob.metadata[:width]
      end
    end

    user = User.create! \
      name: "Analysis Test",
      avatar_with_lazy_analysis: { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }

    # Not analyzed during validation
    assert_nil validated_width

    # Still not analyzed after save
    assert_nil user.avatar_with_lazy_analysis.blob.metadata[:width]
  ensure
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "global ActiveStorage.analyze = :immediately enables immediate analysis" do
    original = ActiveStorage.analyze
    ActiveStorage.analyze = :immediately

    validated_width = nil

    User.validate do
      if avatar.attached? && avatar.blob
        validated_width = avatar.blob.metadata[:width]
      end
    end

    User.create! \
      name: "Analysis Test",
      avatar: { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }

    assert_equal 4104, validated_width
  ensure
    ActiveStorage.analyze = original
    User.clear_validators!
    User.validates :name, presence: true
  end

  test "analyze: :lazily skips enqueuing AnalyzeJob" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      @user.avatar_with_lazy_analysis.attach(blob)
    end
  end

  test "analyze: :later enqueues AnalyzeJob" do
    blob = directly_upload_file_blob(filename: "racecar.jpg")

    assert_enqueued_with job: ActiveStorage::AnalyzeJob do
      @user.avatar_with_later_analysis.attach(blob)
    end
  end

  test "global ActiveStorage.analyze = :lazily skips enqueuing AnalyzeJob" do
    original = ActiveStorage.analyze
    ActiveStorage.analyze = :lazily

    blob = directly_upload_file_blob(filename: "racecar.jpg")

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      @user.avatar.attach(blob)
    end
  ensure
    ActiveStorage.analyze = original
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
    ensure
      owner.class.clear_validators!
      owner.class.validates :name, presence: true
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

    def assert_create_variants_job(blob:, variants:, &block)
      assert_enqueued_with(
        job: ActiveStorage::CreateVariantsJob,
        args: [ blob, variants:, process: :later ], &block
      )
    end
end
