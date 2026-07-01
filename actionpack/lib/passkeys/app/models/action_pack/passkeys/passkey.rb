# frozen_string_literal: true

module ActionPack
  module Passkeys
    # = Action Pack Passkey
    #
    # Provides WebAuthn passkey registration and authentication backed by Active Record.
    #
    # Passkeys are scoped to a polymorphic +holder+ (typically a User or Identity) and store the
    # credential ID, public key, sign count, and transport hints needed for the WebAuthn ceremonies.
    #
    # == Registration
    #
    # Generate options for the browser's +navigator.credentials.create()+ call, then register the
    # response:
    #
    #   options = ActionPack::Passkeys::Passkey.registration_options(holder: current_user)
    #   # Pass options to the browser
    #
    #   passkey = ActionPack::Passkeys::Passkey.register(params[:passkey], holder: current_user)
    #
    # == Authentication
    #
    # Generate options for the browser's +navigator.credentials.get()+ call, then authenticate the
    # response:
    #
    #   options = ActionPack::Passkeys::Passkey.authentication_options
    #   # Pass options to the browser
    #
    #   passkey = ActionPack::Passkeys::Passkey.authenticate(params[:passkey])
    #
    # == Holder Integration
    #
    # Call +has_passkeys+ in the model to set up the association and configure ceremony options
    # per-holder. See ActionPack::Passkeys::Holder for details.
    class Passkey < ActionPack::Passkeys.parent_class_name.constantize
      belongs_to :holder, polymorphic: true
      serialize :transports, coder: JSON, type: Array, default: []

      class << self
        # Returns a CreationOptions object for the given +holder+, suitable for passing to the
        # browser's +navigator.credentials.create()+ call. Merges global defaults from the Rails
        # configuration, holder-specific options from +holder.passkey_registration_options+, and any
        # additional +options+ overrides.
        def registration_options(holder:, **options)
          ActionPack::WebAuthn::PublicKeyCredential.creation_options(
            timeout: ActionPack::Passkeys.registration_timeout,
            **ActionPack::Passkeys.default_registration_options.to_h,
            **holder.passkey_registration_options.to_h,
            **options
          )
        end

        # Verifies the attestation response from the browser and persists a new passkey record.
        # The +passkey+ hash should contain +client_data_json+, +attestation_object+, and +transports+
        # as submitted by the registration form. The challenge is extracted from the authenticator's
        # +clientDataJSON+ response and verified server-side. Any additional +attributes+ (e.g. +holder+)
        # are passed through to +create!+.
        #
        # Returns the persisted Passkey record, or +nil+ if the attestation is invalid. Use #register!
        # to raise ActionPack::WebAuthn::InvalidResponseError instead.
        def register(passkey, **attributes)
          register!(passkey, **attributes)
        rescue ActionPack::WebAuthn::InvalidResponseError
          nil
        end

        # Same as #register, but raises ActionPack::WebAuthn::InvalidResponseError instead of
        # returning +nil+ if the attestation is invalid.
        #
        # The user_verification requirement enforced during verification is the same one that
        # would be used to build this holder's #registration_options (global defaults overridden
        # by the holder's own +passkey_registration_options+).
        def register!(passkey_params, **attributes)
          passkey = new(**attributes)
          registration_options = self.registration_options(holder: passkey.holder)

          credential = ActionPack::WebAuthn::PublicKeyCredential.register(
            passkey_params,
            user_verification: registration_options.user_verification
          )

          passkey.assign_attributes(**credential.to_h, **attributes)
          passkey.save!
          passkey
        end

        # Returns a RequestOptions object suitable for passing to the browser's
        # +navigator.credentials.get()+ call. When a +holder+ is provided, their existing credentials
        # are included so the browser can offer them for selection. Merges global defaults, holder
        # options, and any additional +options+ overrides.
        def authentication_options(holder: nil, **options)
          ActionPack::WebAuthn::PublicKeyCredential.request_options(
            timeout: ActionPack::Passkeys.authentication_timeout,
            **ActionPack::Passkeys.default_authentication_options.to_h,
            **holder&.passkey_authentication_options.to_h,
            **options
          )
        end

        # Looks up a passkey by credential ID and verifies the assertion response from the browser.
        # Returns the authenticated Passkey record, or +nil+ if the credential is not found or
        # verification fails. Use #authenticate! to raise instead.
        def authenticate(passkey)
          find_by(credential_id: passkey[:id])&.authenticate(passkey)
        end

        # Same as #authenticate, but raises ActiveRecord::RecordNotFound if the credential is not
        # found, or ActionPack::WebAuthn::InvalidResponseError if verification fails.
        def authenticate!(passkey)
          find_by!(credential_id: passkey[:id]).authenticate!(passkey)
        end
      end

      # Verifies the assertion response against this passkey's stored credential and updates the
      # +sign_count+ and +backed_up+ attributes. Returns +self+ on success, or +nil+ if the
      # response is invalid. Use #authenticate! to raise ActionPack::WebAuthn::InvalidResponseError
      # instead.
      def authenticate(passkey)
        authenticate!(passkey)
      rescue ActionPack::WebAuthn::InvalidResponseError
        nil
      end

      # Same as #authenticate, but raises ActionPack::WebAuthn::InvalidResponseError instead of
      # returning +nil+ if the response is invalid.
      #
      # The user_verification requirement enforced during verification is the same one that
      # would be used to build this holder's #authentication_options (global defaults overridden
      # by the holder's own +passkey_authentication_options+).
      def authenticate!(passkey)
        credential = to_public_key_credential
        authentication_options = self.class.authentication_options(holder: holder)

        credential.authenticate(passkey, user_verification: authentication_options.user_verification)
        update!(sign_count: credential.sign_count, backed_up: credential.backed_up)

        self
      end

      # Returns an ActionPack::WebAuthn::PublicKeyCredential initialized from this record's stored
      # credential data.
      def to_public_key_credential
        ActionPack::WebAuthn::PublicKeyCredential.new(
          id: credential_id,
          public_key: public_key,
          sign_count: sign_count,
          transports: transports
        )
      end
    end
  end
end
