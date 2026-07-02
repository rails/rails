# frozen_string_literal: true

require_relative "../web_authn_test_helper"
require "action_pack/passkeys"
require_relative "../../lib/passkeys/app/controllers/action_pack/passkeys/challenges_controller"

class ActionPack::Passkeys::ChallengesControllerTest < ActionController::TestCase
  tests ActionPack::Passkeys::ChallengesController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      post "/rails/action_pack/passkey/challenge" => "action_pack/passkeys/challenges#create"
    end
  end

  teardown do
    ActionPack::Passkeys.default_registration_options = {}
    ActionPack::Passkeys.default_authentication_options = {}
  end

  test "create returns a fresh challenge and the authentication timeout, in milliseconds, by default" do
    post :create

    assert_response :success
    assert_equal "application/json", response.media_type

    assert response.parsed_body["challenge"].present?
    assert_equal ActionPack::WebAuthn::PublicKeyCredential::RequestOptions::DEFAULT_TIMEOUT.in_milliseconds.to_i, response.parsed_body["timeout"]
  end

  test "create returns the registration timeout, in milliseconds, for a registration purpose" do
    post :create, params: { purpose: "registration" }

    assert_response :success
    assert_equal ActionPack::WebAuthn::PublicKeyCredential::CreationOptions::DEFAULT_TIMEOUT.in_milliseconds.to_i, response.parsed_body["timeout"]
  end

  test "create returns the configured default timeout, in milliseconds, for each purpose" do
    ActionPack::Passkeys.default_registration_options = { timeout: 42 }
    ActionPack::Passkeys.default_authentication_options = { timeout: 24 }

    post :create, params: { purpose: "registration" }
    assert_equal 42_000, response.parsed_body["timeout"]

    post :create
    assert_equal 24_000, response.parsed_body["timeout"]
  end

  test "create returns a nil timeout when the purpose's default timeout is configured as nil" do
    ActionPack::Passkeys.default_authentication_options = { timeout: nil }

    post :create

    assert_response :success
    assert_nil response.parsed_body["timeout"]
  end

  test "create returns a different challenge on every request" do
    post :create
    first_challenge = response.parsed_body["challenge"]

    post :create
    second_challenge = response.parsed_body["challenge"]

    assert_not_equal first_challenge, second_challenge
  end
end
