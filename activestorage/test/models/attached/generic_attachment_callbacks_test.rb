# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"
require "minitest/mock"

class ActiveStorage::GenericAttachmentCallbacksTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  setup do
    @directory = Dir.mktmpdir("active_storage_attachment_callbacks")
    configurations = Rails.configuration.active_storage.service_configurations.merge(
      "mirror" => { service: "Mirror", primary: "primary", mirrors: ["secondary"] },
      "primary" => { service: "Disk", root: File.join(@directory, "primary") },
      "secondary" => { service: "Disk", root: File.join(@directory, "secondary") }
    )
    ActiveStorage::Services.registry = ActiveStorage::Service::Registry.new(configurations)
    ActiveStorage::Services.default = @service = ActiveStorage::Services.fetch(:mirror)
    @owner_class.has_one_attached :picture, analyze: :later do |attachment|
      attachment.variant :immediate, resize_to_limit: [10, 10], process: :immediately
      attachment.variant :later, resize_to_limit: [20, 20], process: :later
      attachment.variant :lazy, resize_to_limit: [30, 30], process: :lazily
    end
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  [:blob, :signed_id].each do |attachable|
    test "existing #{attachable} runs attachment callbacks after commit" do
      blob = uploaded_image(direct: attachable == :signed_id)
      owner = @owner_class.new(name: "Dorian")
      owner.picture = attachable == :signed_id ? blob.signed_id : blob
      immediate, later, lazy = picture_variants(owner)

      ActiveStorage::InMemoryBackend.transaction do
        owner.save!

        assert_no_enqueued_jobs
        assert_not blob.reload.analyzed?
        assert_not @service.mirrors.first.exist?(blob.key)
        [immediate, later, lazy].each { |variant| assert_not variant.processed? }
      end

      assert immediate.processed?
      assert_equal 10, read_image(immediate).width
      assert_not later.processed?
      assert_not lazy.processed?
      assert_enqueued_with(job: ActiveStorage::MirrorJob, args: [blob.key, { checksum: blob.checksum }])
      assert_enqueued_with(job: ActiveStorage::AnalyzeJob, args: [blob])
      assert_enqueued_with(job: ActiveStorage::CreateVariantsJob, args: [blob, { variants: [{ resize_to_limit: [20, 20] }], process: :later }])

      perform_enqueued_jobs { perform_enqueued_jobs }

      assert blob.reload.analyzed?
      assert_equal file_fixture("racecar.jpg").binread, @service.mirrors.first.download(blob.key)
      assert_equal 20, read_image(later).width
      assert_not lazy.processed?

      assert_no_enqueued_jobs do
        ActiveStorage::InMemoryBackend.transaction { owner.picture.attachment.save! }
      end
    end
  end

  test "fresh uploads run attachment callbacks only after bytes are uploaded at commit" do
    owner = @owner_class.new(name: "Dorian")
    owner.picture = { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }
    blob = owner.picture.blob
    immediate, later, lazy = picture_variants(owner)

    perform_enqueued_jobs do
      ActiveStorage::InMemoryBackend.transaction do
        owner.save!

        assert_no_performed_jobs
        assert_not @service.primary.exist?(blob.key)
        assert_not blob.analyzed?
        [immediate, later, lazy].each { |variant| assert_not variant.processed? }
      end
    end

    assert blob.reload.analyzed?
    assert_equal file_fixture("racecar.jpg").binread, @service.mirrors.first.download(blob.key)
    assert_equal 10, read_image(immediate).width
    assert_equal 20, read_image(later).width
    assert_not lazy.processed?
    assert_performed_with(job: ActiveStorage::CreateVariantsJob, args: [blob, { variants: [{ resize_to_limit: [20, 20] }], process: :later }])
    assert_no_performed_jobs only: ActiveStorage::AnalyzeJob
  end

  [:blob, :fresh].each do |attachable|
    test "rolling back #{attachable} attachments suppresses upload callbacks" do
      owner = @owner_class.new(name: "Dorian")
      owner.picture = if attachable == :blob
        uploaded_image
      else
        { io: file_fixture("racecar.jpg").open, filename: "racecar.jpg", content_type: "image/jpeg" }
      end
      blob = owner.picture.blob

      assert_raises(RuntimeError, "rollback") do
        ActiveStorage::InMemoryBackend.transaction do
          owner.save!
          raise "rollback"
        end
      end

      assert_no_enqueued_jobs
      assert_not blob.analyzed?
      assert_not @service.mirrors.first.exist?(blob.key)
      picture_variants(owner).each { |variant| assert_not variant.processed? }
      assert_equal attachable == :blob, @service.primary.exist?(blob.key)
    end
  end

  test "failed owner persistence does not run attachment callbacks" do
    owner = @owner_class.new
    owner.picture = uploaded_image

    ActiveStorage::InMemoryBackend.transaction { assert_not owner.save }

    assert_no_enqueued_jobs
    assert_not owner.picture.blob.analyzed?
    picture_variants(owner).each { |variant| assert_not variant.processed? }
  end

  test "already processed immediate variants are skipped while later variants are queued" do
    blob = uploaded_image
    owner = @owner_class.new(name: "Dorian")
    owner.picture = blob
    owner.picture.variant(:immediate).processed
    clear_enqueued_jobs
    owner.picture.attachment.immediate_variants_processed = true

    ActiveStorage::CreateVariantsJob.stub(:perform_now, ->(*) { flunk "Immediate variants were already processed" }) do
      ActiveStorage::InMemoryBackend.transaction { owner.save! }
    end

    assert_enqueued_with(job: ActiveStorage::CreateVariantsJob, args: [blob, { variants: [{ resize_to_limit: [20, 20] }], process: :later }])
    assert_equal 10, read_image(owner.picture.variant(:immediate)).width
  end

  private
    def uploaded_image(direct: false)
      data = file_fixture("racecar.jpg").binread
      blob = if direct
        ActiveStorage.blob_class.create_before_direct_upload!(
          filename: "racecar.jpg", content_type: "image/jpeg", byte_size: data.bytesize,
          checksum: @service.compute_checksum(StringIO.new(data))
        ).tap { |blob| @service.primary.upload(blob.key, StringIO.new(data), checksum: blob.checksum) }
      else
        create_memory_blob(filename: "racecar.jpg", data: data, content_type: "image/jpeg")
      end
      clear_enqueued_jobs
      blob
    end

    def picture_variants(owner)
      [:immediate, :later, :lazy].map { |name| owner.picture.variant(name) }
    end
end
