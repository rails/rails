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
    algorithm = :MD5
    digest_expected = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum_expected = ActiveStorage::Checksum.new(digest_expected, algorithm)

    cksum = ActiveStorage::Checksum.new(digest_expected, algorithm)

    assert_equal cksum_expected.algorithm, cksum.algorithm
    assert_equal cksum_expected.digest, cksum.digest
    assert_equal cksum_expected, cksum
  end

  test "not equality when digests are not equal" do
    algorithm = :MD5
    digest_expected = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum_expected = ActiveStorage::Checksum.new(digest_expected, algorithm)

    digest_different = "b8QiIzpAp1ofAo4Rw80RQA=="
    cksum = ActiveStorage::Checksum.new(digest_different, algorithm)

    assert_not_equal cksum_expected.digest, cksum.digest
    assert_not_equal cksum_expected, cksum
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

    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal ActiveStorage::Checksum.dump(cksum), "#{algorithm}:#{digest}"
  end

  test "to_s returns nil when no digest" do
    cksum = ActiveStorage::Checksum.new(nil)

    assert_nil cksum.to_s
  end

  test "to_s returns MD5 digest for MD5 algorithm" do
    algorithm = :MD5
    digest = "ixqZU8RhEpaoJ6v4xHgE1w=="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal cksum.to_s, cksum.digest
  end

  test "to_s returns concatenated format" do
    algorithm = :SHA256
    digest = "GF+NsyJx/iX1Yab8k4suJkMG7DBO2lGAB9F2SCY4GWk="
    cksum = ActiveStorage::Checksum.new(digest, algorithm)

    assert_equal cksum.to_s, "#{algorithm}:#{digest}"
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

end
