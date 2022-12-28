# frozen_string_literal: true

require_relative "../abstract_unit"
require_relative "message_metadata_tests"

class MessageVerifierMetadataTest < ActiveSupport::TestCase
  include MessageMetadataTests

  test "#verify raises when :purpose does not match" do
    each_scenario do |data, verifier|
      assert_equal data, verifier.verify(verifier.generate(data, purpose: "x"), purpose: "x")

      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        verifier.verify(verifier.generate(data, purpose: "x"), purpose: "y")
      end

      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        verifier.verify(verifier.generate(data), purpose: "y")
      end

      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        verifier.verify(verifier.generate(data, purpose: "x"))
      end
    end
  end

  test "#verify raises when message is expired via :expires_at" do
    freeze_time do
      each_scenario do |data, verifier|
        message = verifier.generate(data, expires_at: 1.second.from_now)

        travel 0.5.seconds, with_usec: true
        assert_equal data, verifier.verify(message)

        travel 0.5.seconds, with_usec: true
        assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
          verifier.verify(message)
        end
      end
    end
  end

  test "#verify raises when message is expired via :expires_in" do
    freeze_time do
      each_scenario do |data, verifier|
        message = verifier.generate(data, expires_in: 1.second)

        travel 0.5.seconds, with_usec: true
        assert_equal data, verifier.verify(message)

        travel 0.5.seconds, with_usec: true
        assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
          verifier.verify(message)
        end
      end
    end
  end

  private
    def make_codec(**options)
      ActiveSupport::MessageVerifier.new("secret", **options)
    end

    def encode(data, verifier, **options)
      verifier.generate(data, **options)
    end

    def decode(message, verifier, **options)
      verifier.verified(message, **options)
    end
end
