# frozen_string_literal: true

module ActionPack
  module WellKnown
    # = Action Pack Well-Known WebAuthn Controller
    #
    # Serves the WebAuthn document at +/.well-known/webauthn+. Browsers fetch
    # this file from the relying party ID's host to learn which other origins
    # may use credentials scoped to that relying party ID, letting a single set
    # of passkeys work across several domains via Related Origin Requests.
    #
    # == Route
    #
    # Mounted at +/.well-known/webauthn+ when
    # +config.action_pack.passkey.related_origins+ is configured.
    #
    class WebauthnController < ActionController::Base
      def show
        render json: { origins: ActionPack::Passkeys.related_origins }
      end
    end
  end
end
