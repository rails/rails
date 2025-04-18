# frozen_string_literal: true

require_relative "abstract_unit"
require_relative "rotation_coordinator_tests"

class MessageEncryptorsTest < ActiveSupport::TestCase
  include RotationCoordinatorTests

  test "can override secret generator" do
    secret_generator = ->(salt, secret_length:) { salt[0] * secret_length }
    coordinator = make_coordinator.rotate(secret_generator: secret_generator)

    assert_equal "message", roundtrip("message", coordinator["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], coordinator["salt"])
  end

  test "supports arbitrary secret generator kwargs" do
    secret_generator = ->(salt, secret_length:, foo:, bar: nil) { foo[bar] * secret_length }
    coordinator = ActiveSupport::MessageEncryptors.new(&secret_generator)
    coordinator.rotate(foo: "foo", bar: 0)

    assert_equal "message", roundtrip("message", coordinator["salt"])
  end

  test "supports arbitrary secret generator kwargs when using #rotate block" do
    secret_generator = ->(salt, secret_length:, foo:, bar: nil) { foo[bar] * secret_length }
    coordinator = ActiveSupport::MessageEncryptors.new(&secret_generator)
    coordinator.rotate { { foo: "foo", bar: 0 } }

    assert_equal "message", roundtrip("message", coordinator["salt"])
  end

  test "supports separate secrets for encryption and signing" do
    secret_generator = proc { |*args, **kwargs| [SECRET_GENERATOR.call(*args, **kwargs), "signing secret"] }
    coordinator = ActiveSupport::MessageEncryptors.new(&secret_generator)
    coordinator.rotate_defaults

    assert_equal "message", roundtrip("message", coordinator["salt"])
    assert_nil roundtrip("message", @coordinator["salt"], coordinator["salt"])
  end

  private
    SECRET_GENERATOR = proc { |salt, secret_length:| "".ljust(secret_length, salt) }

    def make_coordinator
      ActiveSupport::MessageEncryptors.new(&SECRET_GENERATOR)
    end

    def roundtrip(message, encryptor, decryptor = encryptor)
      decryptor.decrypt_and_verify(encryptor.encrypt_and_sign(message))
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end
end
