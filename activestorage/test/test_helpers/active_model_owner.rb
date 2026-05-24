# frozen_string_literal: true

require_relative "../fixtures/active_storage/in_memory_backend"
require_relative "../fixtures/active_model_owner"

module ActiveStorage::ActiveModelOwnerTestSupport
  extend ActiveSupport::Concern
  include ActiveJob::TestHelper

  included do
    setup do
      @raw_blob_class = ActiveStorage.blob_class_name
      @raw_attachment_class = ActiveStorage.attachment_class_name
      @raw_variant_record_class = ActiveStorage.variant_record_class_name
      @services_registry = ActiveStorage::Services.registry
      @services_default = ActiveStorage::Services.default
      @track_variants = ActiveStorage.track_variants
      ActiveStorage.track_variants = false

      ActiveStorage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
      ActiveStorage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
      ActiveStorage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"
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
      ActiveStorage.blob_class = @raw_blob_class
      ActiveStorage.attachment_class = @raw_attachment_class
      ActiveStorage.variant_record_class = @raw_variant_record_class
      ActiveStorage::Services.registry = @services_registry
      ActiveStorage::Services.default = @services_default
      clear_enqueued_jobs
      clear_performed_jobs
    end
  end

  private
    def create_memory_direct_upload
      data = file_fixture("racecar.jpg").binread
      checksum = ActiveStorage::Services.default.compute_checksum(StringIO.new(data))
      ActiveStorage.blob_class.create_before_direct_upload!(
        filename: "racecar.bin", byte_size: data.bytesize, checksum: checksum, content_type: "application/octet-stream"
      ).tap do |blob|
        blob.service.upload(blob.key, StringIO.new(data), checksum: checksum)
      end
    end

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

    def lifecycle_upload(content)
      { io: StringIO.new(content), filename: "#{content}.txt", content_type: "text/plain" }
    end

    def defer_lifecycle_commits(owner)
      owner.define_singleton_method(:run_callbacks) do |name, &block|
        name == :commit ? block&.call : super(name, &block)
      end
      owner
    end

    def commit_lifecycle(owner, result = true)
      ActiveSupport::Callbacks.instance_method(:run_callbacks).bind_call(owner, :commit) { result }
    end
end
