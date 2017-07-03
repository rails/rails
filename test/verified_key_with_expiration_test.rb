require "test_helper"
require "active_support/core_ext/securerandom"

class ActiveFile::VerifiedKeyWithExpirationTest < ActiveSupport::TestCase
  FIXTURE_KEY = SecureRandom.base58(24)

  test "without expiration" do
    encoded_key = ActiveFile::VerifiedKeyWithExpiration.encode(FIXTURE_KEY)
    assert_equal FIXTURE_KEY, ActiveFile::VerifiedKeyWithExpiration.decode(encoded_key)
  end
end
