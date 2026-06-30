# frozen_string_literal: true

module ActionPack
  # = Action Pack Passkey Challenges Controller
  #
  # Generates fresh WebAuthn challenges for passkey ceremonies. The companion
  # JavaScript calls this endpoint before initiating a registration or
  # authentication ceremony so that the challenge is issued just-in-time rather
  # than embedded in the initial page load.
  #
  # The generated challenge is returned in the JSON response body. The challenge
  # is a signed, expiring token that the server can verify on the subsequent
  # form submission without needing server-side state — the challenge is
  # extracted from the authenticator's +clientDataJSON+ response.
  #
  # == Route
  #
  # By default mounted at +/rails/action_pack/passkey/challenge+ (configurable
  # via +config.action_pack.passkey.routes_prefix+).
  #
  class Passkeys::ChallengesController < ActionController::Base
    include ActionPack::Passkeys::Request

    skip_forgery_protection

    # Generates a fresh challenge and returns it as JSON. Accepts an optional
    # +purpose+ parameter ("registration" or "authentication") to select the
    # appropriate challenge expiration. Defaults to "authentication".
    def create
      render json: { challenge: create_passkey_challenge }
    end

    private
      def create_passkey_challenge
        ActionPack::WebAuthn::PublicKeyCredential::Options.new(
          timeout: timeout,
          challenge_purpose: challenge_purpose
        ).challenge
      end

      def challenge_purpose
        if params[:purpose] == "registration"
          "registration"
        else
          "authentication"
        end
      end

      def timeout
        if challenge_purpose == "registration"
          ActionPack::Passkeys.registration_timeout
        else
          ActionPack::Passkeys.authentication_timeout
        end
      end
  end
end
