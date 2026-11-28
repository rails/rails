# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::MirrorJobTest < ActiveJob::TestCase
  setup do
    @service  = ActiveStorage::Blob.services.fetch(:mirror)
    @key      = SecureRandom.base58(24)
    @data     = "Something else entirely!"
    @checksum = OpenSSL::Digest::MD5.base64digest(@data)

    @service.primary.upload @key, StringIO.new(@data), checksum: @checksum
  end

  teardown { @service.delete @key }

  test "mirrors through the named service rather than the default one" do
    assert_not_equal @service, ActiveStorage::Blob.service

    ActiveStorage::MirrorJob.perform_now @key, checksum: @checksum, service_name: :mirror

    @service.mirrors.each do |mirror|
      assert_equal @data, mirror.download(@key)
    end
  end

  test "mirrors through the default service without a service name" do
    with_service("mirror") do
      ActiveStorage::MirrorJob.perform_now @key, checksum: @checksum
    end

    @service.mirrors.each do |mirror|
      assert_equal @data, mirror.download(@key)
    end
  end

  test "ignores a default service that does not mirror" do
    assert_nothing_raised do
      ActiveStorage::MirrorJob.perform_now @key, checksum: @checksum
    end

    @service.mirrors.each do |mirror|
      assert_not mirror.exist?(@key)
    end
  end
end
