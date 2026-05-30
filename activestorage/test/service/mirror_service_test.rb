# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::MirrorServiceTest < ActiveSupport::TestCase
  mirror_config = (1..3).to_h do |i|
    [ "mirror_#{i}",
      service: "Disk",
      root: Dir.mktmpdir("active_storage_tests_mirror_#{i}") ]
  end

  config = mirror_config.merge \
    mirror:  { service: "Mirror", primary: "primary", mirrors: mirror_config.keys },
    primary: { service: "Disk", root: Dir.mktmpdir("active_storage_tests_primary") }

  SERVICE = ActiveStorage::Service.configure :mirror, config

  include ActiveStorage::Service::SharedServiceTests
  include ActiveJob::TestHelper

  test "name" do
    assert_equal :mirror, @service.name
  end

  test "uploading to all services" do
    old_service = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = @service

    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    io       = StringIO.new(data)
    checksum = OpenSSL::Digest::MD5.base64digest(data)

    assert_performed_jobs 1, only: ActiveStorage::MirrorJob do
      @service.upload key, io.tap(&:read), checksum: checksum
    end

    assert_predicate io, :eof?

    assert_equal data, @service.primary.download(key)
    @service.mirrors.each do |mirror|
      assert_equal data, mirror.download(key)
    end
  ensure
    @service.delete key
    ActiveStorage::Blob.service = old_service
  end

  test "downloading from primary service" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = OpenSSL::Digest::MD5.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum

    assert_equal data, @service.download(key)
  end

  test "deleting from all services" do
    @service.delete @key

    assert_not SERVICE.primary.exist?(@key)
    SERVICE.mirrors.each do |mirror|
      assert_not mirror.exist?(@key)
    end
  end

  test "mirroring a file from the primary service to secondary services where it doesn't exist" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = OpenSSL::Digest::MD5.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum
    @service.mirrors.third.upload key, StringIO.new("Surprise!")

    @service.mirror key, checksum: checksum
    assert_equal data, @service.mirrors.first.download(key)
    assert_equal data, @service.mirrors.second.download(key)
    assert_equal "Surprise!", @service.mirrors.third.download(key)
  end

  test "mirroring a file without a checksum does not raise" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"

    @service.primary.upload key, StringIO.new(data)

    assert_nothing_raised { @service.mirror key, checksum: nil }

    @service.mirrors.each do |mirror|
      assert_equal data, mirror.download(key)
    end
  ensure
    @service.delete key
  end

  test "mirrors receive correct content when io is at EOF on yield" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"

    @service.primary.upload key, StringIO.new(data)

    # Simulate io being at EOF when yielded (as happens when Tempfile.is_a?(File)
    # and compute_checksum takes the File branch without rewinding).
    @service.primary.define_singleton_method(:open) do |k, **opts, &block|
      io = StringIO.new(data)
      io.read # advance to EOF
      block.call(io)
    end

    @service.mirror key, checksum: nil

    @service.mirrors.each do |mirror|
      assert_equal data, mirror.download(key)
    end
  ensure
    @service.delete key
  end

  test "exist? checks run in parallel across mirrors" do
    key  = SecureRandom.base58(24)
    data = "Something else entirely!"

    @service.primary.upload key, StringIO.new(data)

    threads = Concurrent::Array.new
    @service.mirrors.each do |mirror|
      mirror.define_singleton_method(:exist?) do |k|
        threads << Thread.current
        super(k)
      end
    end

    @service.mirror key, checksum: nil

    assert_operator threads.map(&:object_id).uniq.size, :>, 1,
      "Expected exist? checks to run on multiple threads, got: #{threads.map(&:object_id).uniq.size}"
  ensure
    @service.delete key
  end

  test "uploads to mirrors run in parallel" do
    key      = SecureRandom.base58(24)
    data     = "Something else entirely!"
    checksum = OpenSSL::Digest::MD5.base64digest(data)

    @service.primary.upload key, StringIO.new(data), checksum: checksum

    threads = Concurrent::Array.new
    @service.mirrors.each do |mirror|
      mirror.define_singleton_method(:upload) do |k, io, **opts|
        threads << Thread.current
        super(k, io, **opts)
      end
    end

    @service.mirror key, checksum: checksum

    assert_operator threads.map(&:object_id).uniq.size, :>, 1,
      "Expected uploads to run on multiple threads, got: #{threads.map(&:object_id).uniq.size}"
    @service.mirrors.each { |mirror| assert_equal data, mirror.download(key) }
  ensure
    @service.delete key
  end

  test "URL generation in primary service" do
    filename = ActiveStorage::Filename.new("test.txt")

    freeze_time do
      assert_equal @service.primary.url(@key, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain"),
        @service.url(@key, expires_in: 2.minutes, disposition: :inline, filename: filename, content_type: "text/plain")
    end
  end

  test "path for file in primary service" do
    assert_equal @service.primary.path_for(@key), @service.path_for(@key)
  end
end
