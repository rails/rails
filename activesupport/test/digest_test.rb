# frozen_string_literal: true

require_relative "abstract_unit"
require "openssl"

class DigestTest < ActiveSupport::TestCase
  class InvalidDigest; end
  def test_with_default_hash_digest_class
    assert_equal OpenSSL::Digest.hexdigest("MD5", "hello friend"), ActiveSupport::Digest.hexdigest("hello friend")
  end

  def test_with_custom_hash_digest_class
    original_hash_digest_class = ActiveSupport::Digest.hash_digest_class
    ActiveSupport::Digest.hash_digest_class = "SHA1"
    digest = ActiveSupport::Digest.hexdigest("hello friend")

    assert_equal 32, digest.length
    assert_equal OpenSSL::Digest.hexdigest("SHA1", "hello friend")[0...32], digest
  ensure
    ActiveSupport::Digest.hash_digest_class = original_hash_digest_class
  end

  def test_should_raise_argument_error_if_custom_digest_is_missing_hexdigest_method
    assert_deprecated(/Passing a Digest Class to `hash_digest_class=` is deprecated and will be removed in future/) do
      assert_raises(ArgumentError) { ActiveSupport::Digest.hash_digest_class = InvalidDigest }
      assert_raises(ArgumentError) { ActiveSupport::Digest.hash_digest_class = "InvalidDigest" }
    end
  end
end
