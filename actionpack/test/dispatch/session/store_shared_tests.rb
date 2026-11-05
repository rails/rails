# frozen_string_literal: true

require "abstract_unit"
require "active_support/key_generator"
require "active_support/messages/rotation_configuration"

module StoreSharedTests
  extend ActiveSupport::Testing::Declarative
  include CookieAssertions

  SessionKey = "_myapp_session"
  SessionSecret = "b3c631c314c0bbca50c1b2843150fe33"
  SessionSalt   = "authenticated encrypted cookie"

  Generator = ActiveSupport::KeyGenerator.new(SessionSecret, iterations: 1000)
  Rotations = ActiveSupport::Messages::RotationConfiguration.new

  SameSite = proc { :lax }

  Encryptor = ActiveSupport::MessageEncryptor.new(
    Generator.generate_key(SessionSalt, 32), cipher: "aes-256-gcm", serializer: Marshal
  )

  test "default same_site derives SameSite from env" do
    with_test_route_set do
      get "/set_session_value"
      assert_set_cookie_attributes("_myapp_session", "SameSite=Lax")
    end
  end

  test "default same_site follows the SameSite policy in env" do
    with_test_route_set do
      get "/set_session_value", headers: { "action_dispatch.cookies_same_site_protection" => proc { :strict } }
      assert_set_cookie_attributes("_myapp_session", "SameSite=Strict")
    end
  end

  test "explicit same_site sets SameSite" do
    cookie_options(same_site: :strict)

    with_test_route_set do
      get "/set_session_value"
      assert_set_cookie_attributes("_myapp_session", "SameSite=Strict")
    end
  end

  test "explicit nil same_site omits SameSite" do
    cookie_options(same_site: nil)

    with_test_route_set do
      get "/set_session_value"
      assert_not_set_cookie_attributes("_myapp_session", "SameSite")
    end
  end

  private
    # Overwrite `get` to set env hash
    def get(path, **options)
      options[:headers] ||= {}
      options[:headers].tap do |config|
        config["action_dispatch.secret_key_base"] = SessionSecret
        config["action_dispatch.authenticated_encrypted_cookie_salt"] = SessionSalt
        config["action_dispatch.use_authenticated_cookie_encryption"] = true

        config["action_dispatch.key_generator"] ||= Generator
        config["action_dispatch.cookies_rotations"] ||= Rotations

        config["action_dispatch.cookies_same_site_protection"] ||= SameSite
      end

      super
    end

    def cookie_options(options = {})
      (@cookie_options ||= { key: SessionKey }).merge!(options)
    end
end
