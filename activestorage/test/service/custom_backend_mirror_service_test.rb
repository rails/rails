# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::Service::CustomBackendMirrorServiceTest < ActiveSupport::TestCase
  include ActiveStorage::ActiveModelOwnerTestSupport

  setup do
    @directory = Dir.mktmpdir("active_storage_custom_mirrors")
    configurations = Rails.configuration.active_storage.service_configurations.merge(
      "mirror" => { service: "Mirror", primary: "primary", mirrors: ["secondary"] },
      "primary" => { service: "Disk", root: File.join(@directory, "primary") },
      "secondary" => { service: "Disk", root: File.join(@directory, "secondary") }
    )
    ActiveStorage::Services.registry = ActiveStorage::Service::Registry.new(configurations)
    ActiveStorage::Services.default = @service = ActiveStorage::Services.fetch(:mirror)
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test "mirrors a direct upload through a queued job using the configured backend" do
    data = "custom backend direct upload"
    blob = ActiveStorage.blob_class.create_before_direct_upload!(
      filename: "custom.txt", content_type: "text/plain", byte_size: data.bytesize,
      checksum: @service.compute_checksum(StringIO.new(data))
    )
    @service.primary.upload(blob.key, StringIO.new(data), checksum: blob.checksum)

    assert_performed_jobs 1, only: ActiveStorage::MirrorJob do
      blob.mirror_later
    end

    assert_equal data, @service.mirrors.first.download(blob.key)
  end

  test "mirrors metadata from the configured backend with a safe content disposition" do
    data = "<script>alert(1)</script>"
    blob = ActiveStorage.blob_class.create_before_direct_upload!(
      filename: "custom.html", content_type: "text/html", byte_size: data.bytesize,
      checksum: @service.compute_checksum(StringIO.new(data)), metadata: { custom: { author: "Thomas" } }
    )
    @service.primary.upload(blob.key, StringIO.new(data), checksum: blob.checksum)
    uploaded_metadata = nil
    @service.mirrors.first.define_singleton_method(:upload) do |key, io, **options|
      uploaded_metadata = options
      super(key, io, **options)
    end

    @service.mirror(blob.key, checksum: blob.checksum)

    assert_equal data, @service.mirrors.first.download(blob.key)
    assert_equal "application/octet-stream", uploaded_metadata[:content_type]
    assert_equal :attachment, uploaded_metadata[:disposition]
    assert_equal "custom.html", uploaded_metadata[:filename].to_s
    assert_equal({ author: "Thomas" }, uploaded_metadata[:custom_metadata])
  end
end
