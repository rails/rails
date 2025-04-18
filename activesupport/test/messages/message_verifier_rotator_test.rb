# frozen_string_literal: true

require_relative "../abstract_unit"
require_relative "message_rotator_tests"

class MessageVerifierRotatorTest < ActiveSupport::TestCase
  include MessageRotatorTests

  test "rotate digest" do
    assert_rotate [digest: "SHA256"], [digest: "SHA1"], [digest: "MD5"]
  end

  private
    def make_codec(secret = secret("secret"), **options)
      ActiveSupport::MessageVerifier.new(secret, **options)
    end

    def encode(data, verifier, **options)
      verifier.generate(data, **options)
    end

    def decode(message, verifier, **options)
      verifier.verified(message, **options)
    end
end
