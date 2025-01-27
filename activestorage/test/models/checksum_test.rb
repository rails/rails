# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_support/testing/method_call_assertions"

class ActiveStorage::ChecksumTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
  include ActiveJob::TestHelper

  test "new ActiveStorage::Checksum" do
    algorithm = :SHA256
    digest = "GF+NsyJx/iX1Yab8k4suJkMG7DBO2lGAB9F2SCY4GWk="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal cksum.algorithm, algorithm
    assert_equal cksum.digest, digest
  end

  test "new ActiveStorage::Checksum without algorithm assumes MD5" do
    digest = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum = ActiveStorage::Checksum.new(digest)

    assert_equal :MD5, cksum.algorithm
    assert_equal digest, cksum.digest
  end

  test "equality when digest and algorithm are equal" do
    data = "Hello"
    algorithm = :MD5
    digest = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum_expected = ActiveStorage::Checksum.new(digest, algorithm)

    cksum = ActiveStorage::Checksum.base64digest(data, algorithm)

    assert_equal cksum_expected.algorithm, cksum.algorithm
    assert_equal cksum_expected.digest, cksum.digest
    assert_equal cksum_expected, cksum
  end

  test "not equality when digest and algorithm are not equal" do
    data = "Hello"
    algorithm = :MD5
    cksum_expected = ActiveStorage::Checksum.base64digest(data, algorithm)

    different_data = "Goodbye"
    different_algorithm = :CRC32

    cksum_data = ActiveStorage::Checksum.base64digest(different_data, algorithm)
    cksum_algo = ActiveStorage::Checksum.base64digest(data, different_algorithm)


    assert_not_equal cksum_expected.algorithm, cksum_algo.algorithm
    assert_not_equal cksum_expected, cksum_algo

    assert_not_equal cksum_expected.digest, cksum_data.digest
    assert_not_equal cksum_expected, cksum_data
  end

  test "dump returns nil for nil" do
    assert_nil ActiveStorage::Checksum.dump(nil)
  end

  test "dump returns MD5 digest for MD5 algorithm" do
    algorithm = :MD5
    digest = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal ActiveStorage::Checksum.dump(cksum), cksum.digest
  end

  test "dump returns concatenated format" do
    algorithm = :SHA256
    digest = "GF+NsyJx/iX1Yab8k4suJkMG7DBO2lGAB9F2SCY4GWk="
    data = "Hello"
    cksum = ActiveStorage::Checksum.base64digest(data, algorithm)

    assert_equal ActiveStorage::Checksum.dump(cksum), "#{algorithm}:#{digest}"
  end

  test "load returns instance when legacy MD5 format" do
    algorithm = :MD5
    digest = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal ActiveStorage::Checksum.load(digest), cksum
  end

  test "load returns instance when concatenated format" do
    algorithm = :SHA256
    digest = "GF+NsyJx/iX1Yab8k4suJkMG7DBO2lGAB9F2SCY4GWk="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal ActiveStorage::Checksum.load("#{algorithm}:#{digest}"), cksum
  end

  test "load returns nil when nil" do
    assert_nil ActiveStorage::Checksum.load(nil)
  end

  test "implementation_class method calls corresponding method" do
    ActiveStorage::Checksum::SUPPORTED_CHECKSUMS.each do |algo|
      assert_called_with(ActiveStorage::Checksum, algo.downcase, []) do
        ActiveStorage::Checksum.implementation_class(algo)
      end
    end
  end

  test "file calculates base64digest from file" do
    file = file_fixture("racecar.jpg")
    algorithm = :SHA256
    digest = "h8h+qfk9jlcu9t0/OqtweExFyzqDg4gDQmxb9r3qjMI="

    cksum = ActiveStorage::Checksum.file(file, algorithm)

    assert_equal ActiveStorage::Checksum.new(digest, algorithm), cksum
  end

  test "base64digest calculates base64digest from string" do
    algorithm = :SHA256
    digest = "GF+NsyJx/iX1Yab8k4suJkMG7DBO2lGAB9F2SCY4GWk="
    data = "Hello"

    cksum = ActiveStorage::Checksum.base64digest(data, algorithm)

    assert_equal ActiveStorage::Checksum.new(digest, algorithm), cksum
  end

  test "compute_checksum_in_chunks" do
    service = ActiveStorage::Blob.service.try(:primary) || ActiveStorage::Blob.service
    file = file_fixture("racecar.jpg")

    cksum = ActiveStorage::Checksum.compute_checksum_in_chunks(File.open(file), service)
    assert_equal ActiveStorage::Checksum.file(file, service.checksum_algorithm), cksum
  end

  test "md5 returns OpenSSL::Digest::MD5 class" do
    old_class = ActiveStorage::Checksum.instance_variable_get(:@md5_class)
    ActiveStorage::Checksum.instance_variable_set(:@md5_class, nil)

    assert_equal OpenSSL::Digest::MD5, ActiveStorage::Checksum.md5

    ActiveStorage::Checksum.instance_variable_set(:@md5_class, old_class)
  end

  test "md5 returns Digest::MD5 class when OpenSSL unavailable" do
    old_class = ActiveStorage::Checksum.instance_variable_get(:@md5_class)
    ActiveStorage::Checksum.instance_variable_set(:@md5_class, nil)

    OpenSSL::Digest::MD5.stub :hexdigest, proc { |input| raise StandardError } do
      assert_equal Digest::MD5, ActiveStorage::Checksum.md5
    end

    ActiveStorage::Checksum.instance_variable_set(:@md5_class, old_class)
  end
end
