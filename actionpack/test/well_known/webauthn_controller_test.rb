# frozen_string_literal: true

require "abstract_unit"
require "action_pack/passkeys"
require_relative "../../lib/passkeys/app/controllers/action_pack/well_known/webauthn_controller"

class ActionPack::WellKnown::WebauthnControllerTest < ActionController::TestCase
  tests ActionPack::WellKnown::WebauthnController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/.well-known/webauthn" => "action_pack/well_known/webauthn#show"
    end

    ActionPack::Passkeys.related_origins = [ "https://example.com", "https://example.co.uk" ]
  end

  teardown do
    ActionPack::Passkeys.related_origins = []
  end

  test "show returns the configured related origins as JSON" do
    get :show

    assert_response :success
    assert_equal "application/json", response.media_type

    origins = response.parsed_body["origins"]
    assert_kind_of Array, origins
    assert_equal ActionPack::Passkeys.related_origins.sort, origins.sort
  end
end
