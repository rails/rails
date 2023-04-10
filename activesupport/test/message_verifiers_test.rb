# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "rotation_coordinator_tests"

class MessageVerifiersTest < ActiveSupport::TestCase
  include RotationCoordinatorTests

  test "can override secret generator" do
    secret_generator = ->(salt) { salt + "!" }
    coordinator = make_coordinator.rotate(secret_generator: secret_generator)

    assert_equal "message", roundtrip("message", coordinator["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], coordinator["salt"])
  end

  test "supports arbitrary secret generator kwargs" do
    secret_generator = ->(salt, foo:, bar: nil) { foo + bar }
    coordinator = ActiveSupport::MessageVerifiers.new(&secret_generator)
    coordinator.rotate(foo: "foo", bar: "bar")

    assert_equal "message", roundtrip("message", coordinator["salt"])
  end

  test "supports arbitrary secret generator kwargs when using #rotate block" do
    secret_generator = ->(salt, foo:, bar: nil) { foo + bar }
    coordinator = ActiveSupport::MessageVerifiers.new(&secret_generator)
    coordinator.rotate { { foo: "foo", bar: "bar" } }

    assert_equal "message", roundtrip("message", coordinator["salt"])
  end

  private
    def make_coordinator
      ActiveSupport::MessageVerifiers.new { |salt| salt * 10 }
    end

    def roundtrip(message, signer, verifier = signer)
      verifier.verified(signer.generate(message))
    end
end
