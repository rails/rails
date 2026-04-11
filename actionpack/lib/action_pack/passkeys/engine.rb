# frozen_string_literal: true

require "active_record/railtie"
require_relative "../passkeys"
require_relative "../web_authn"
require "active_support/core_ext/numeric/bytes"

module ActionPack
  class Passkeys::Engine < Rails::Engine # :nodoc:
    def self.find_root(from)
      Pathname.new(File.expand_path("../../passkeys", __dir__))
    end

    isolate_namespace ActionPack::Passkeys

    config.action_pack = ActiveSupport::OrderedOptions.new unless config.respond_to?(:action_pack)
    config.action_pack.passkey = ActiveSupport::OrderedOptions.new
    config.action_pack.passkey.parent_class_name = "ApplicationRecord"
    config.action_pack.passkey.routes_prefix = "/rails/action_pack/passkey"
    config.action_pack.passkey.draw_routes = true
    config.action_pack.passkey.challenge_url = nil
    config.action_pack.passkey.default_registration_options = {}
    config.action_pack.passkey.default_authentication_options = {}
    config.action_pack.passkey.registration_challenge_expiration = 10.minutes
    config.action_pack.passkey.authentication_challenge_expiration = 5.minutes
    config.action_pack.passkey.cbor_max_depth = 16
    config.action_pack.passkey.cbor_max_size = 10.megabytes

    initializer "action_pack.passkey.config" do
      passkey_config = config.action_pack.passkey

      ActionPack::Passkeys.parent_class_name = passkey_config.parent_class_name
      ActionPack::Passkeys.default_registration_options = passkey_config.default_registration_options
      ActionPack::Passkeys.default_authentication_options = passkey_config.default_authentication_options
      ActionPack::Passkeys.registration_challenge_expiration = passkey_config.registration_challenge_expiration
      ActionPack::Passkeys.authentication_challenge_expiration = passkey_config.authentication_challenge_expiration
      ActionPack::Passkeys.challenge_url = passkey_config.challenge_url
    end

    initializer "action_pack.passkey.verifier" do
      config.after_initialize do |app|
        ActionPack::WebAuthn.challenge_verifier = app.message_verifier("action_pack.webauthn.challenge")
        ActionPack::WebAuthn.application_name = app.name
      end
    end

    initializer "action_pack.passkey.routes" do |app|
      passkey_config = config.action_pack.passkey

      app.routes.prepend do
        if passkey_config.draw_routes
          scope passkey_config.routes_prefix, as: :passkey do
            post "/challenge" => "action_pack/passkeys/challenges#create", as: :challenge
          end
        end
      end
    end

    initializer "action_pack.passkey.cbor" do
      require "action_pack/web_authn/cbor_decoder"
      ActionPack::WebAuthn::CborDecoder.max_depth = config.action_pack.passkey.cbor_max_depth
      ActionPack::WebAuthn::CborDecoder.max_size = config.action_pack.passkey.cbor_max_size
    end

    initializer "action_pack.passkey.holder" do
      ActiveSupport.on_load(:active_record) do
        include ActionPack::Passkeys::Holder
      end
    end

    initializer "action_pack.passkey.form_helper" do
      ActiveSupport.on_load(:action_view) do
        include ActionPack::Passkeys::FormHelper
      end
    end
  end
end
