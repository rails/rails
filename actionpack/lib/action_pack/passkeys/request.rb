# frozen_string_literal: true

module ActionPack
  # = Action Pack Passkey Request
  #
  # Controller concern that sets up the WebAuthn request context and provides
  # helper methods for passkey registration and authentication. Include this
  # in any controller that handles passkey form submissions.
  #
  # == Registration Example
  #
  #   class PasskeysController < ApplicationController
  #     include ActionPack::Passkeys::Request
  #
  #     def new
  #       @registration_options = passkey_registration_options(holder: Current.user)
  #     end
  #
  #     def create
  #       @passkey = ActionPack::Passkeys::Passkey.register(
  #         passkey_registration_params, holder: Current.user
  #       )
  #       redirect_to settings_path
  #     end
  #   end
  #
  # == Authentication Example
  #
  #   class SessionsController < ApplicationController
  #     include ActionPack::Passkeys::Request
  #
  #     def new
  #       @authentication_options = passkey_authentication_options
  #     end
  #
  #     def create
  #       if passkey = ActionPack::Passkeys::Passkey.authenticate(passkey_authentication_params)
  #         sign_in passkey.holder
  #         redirect_to root_path
  #       else
  #         redirect_to new_session_path, alert: "Authentication failed"
  #       end
  #     end
  #   end
  #
  # == Before Action
  #
  # Automatically populates +ActionPack::WebAuthn::Current+ with the request
  # host and origin.
  #
  module Passkeys::Request
    extend ActiveSupport::Concern

    included do
      before_action do
        ActionPack::WebAuthn::Current.host = request.host
        ActionPack::WebAuthn::Current.origin = request.base_url
      end
    end

    # Returns strong parameters for the passkey registration ceremony.
    def passkey_registration_params(param: :passkey)
      params.expect(param => [ :client_data_json, :attestation_object, transports: [] ])
    end

    # Returns strong parameters for the passkey authentication ceremony.
    def passkey_authentication_params(param: :passkey)
      params.expect(param => [ :id, :client_data_json, :authenticator_data, :signature ])
    end

    # Returns RequestOptions for the authentication ceremony.
    def passkey_authentication_options(**options)
      ActionPack::Passkeys::Passkey.authentication_options(**options)
    end

    # Returns CreationOptions for the registration ceremony.
    def passkey_registration_options(**options)
      ActionPack::Passkeys::Passkey.registration_options(**options)
    end
  end
end
