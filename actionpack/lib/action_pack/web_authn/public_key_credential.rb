# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn Public Key Credential
    #
    # Represents a WebAuthn public key credential and orchestrates the registration
    # and authentication ceremonies. During registration (+.register+), it verifies
    # the attestation response and returns a new credential. During authentication
    # (+#authenticate+), it verifies the assertion response against the stored
    # public key.
    #
    # == Registration
    #
    #   credential = ActionPack::WebAuthn::PublicKeyCredential.register(
    #     params[:passkey],
    #     origin: ActionPack::WebAuthn::Current.origin
    #   )
    #
    #   credential.id         # => Base64URL-encoded credential ID
    #   credential.public_key # => OpenSSL::PKey::EC
    #   credential.sign_count # => 0
    #
    # == Authentication
    #
    #   credential = ActionPack::WebAuthn::PublicKeyCredential.new(
    #     id: stored_credential_id,
    #     public_key: stored_public_key,
    #     sign_count: stored_sign_count
    #   )
    #
    #   credential.authenticate(params[:passkey])
    #
    # == Ceremony Options
    #
    # Use +.creation_options+ and +.request_options+ to generate the JSON options
    # passed to the browser's +navigator.credentials.create()+ and
    # +navigator.credentials.get()+ calls.
    #
    # == Attributes
    #
    # [+id+]
    #   The Base64URL-encoded credential identifier.
    #
    # [+public_key+]
    #   The OpenSSL public key for signature verification.
    #
    # [+sign_count+]
    #   The signature counter, used for replay detection.
    #
    # [+aaguid+]
    #   The authenticator attestation GUID (set during registration).
    #
    # [+relying_party_id+]
    #   The relying party ID the credential is scoped to. This is set during registration.
    #
    # [+backed_up+]
    #   Whether the credential is backed up to cloud storage (synced passkey).
    #
    # [+transports+]
    #   Transport hints (e.g., "internal", "usb", "ble", "nfc").
    #
    class PublicKeyCredential
      extend ActiveSupport::Autoload

      autoload :CreationOptions
      autoload :Options
      autoload :RequestOptions

      attr_reader :id, :public_key, :sign_count, :aaguid, :relying_party_id, :backed_up, :transports

      class << self
        # Returns a RequestOptions object for the authentication ceremony.
        # Credentials responding to +to_public_key_credential+ are automatically
        # transformed.
        def request_options(**attributes)
          attributes[:credentials] = transform_credentials(attributes[:credentials]) if attributes[:credentials]

          ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(**attributes)
        end

        # Returns a CreationOptions object for the registration ceremony.
        # Credentials in +exclude_credentials+ responding to
        # +to_public_key_credential+ are automatically transformed.
        def creation_options(**attributes)
          attributes[:exclude_credentials] = transform_credentials(attributes[:exclude_credentials]) if attributes[:exclude_credentials]

          ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(**attributes)
        end

        # Verifies an attestation response from the browser and returns a new
        # PublicKeyCredential with the registered credential data.
        #
        # Raises +InvalidResponseError+ if the attestation is invalid.
        def register(params, origin: ActionPack::WebAuthn::Current.origin)
          response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
            client_data_json: params[:client_data_json],
            attestation_object: params[:attestation_object],
            origin: origin
          )

          response.validate!

          new(
            id: response.attestation.credential_id,
            public_key: response.attestation.public_key,
            sign_count: response.attestation.sign_count,
            aaguid: response.attestation.aaguid,
            relying_party_id: response.relying_party.id,
            backed_up: response.attestation.backed_up?,
            transports: Array(params[:transports])
          )
        end

        private
          def transform_credentials(credentials)
            Array(credentials).map do |credential|
              if credential.respond_to?(:to_public_key_credential)
                credential.to_public_key_credential
              else
                credential
              end
            end
          end
      end

      def initialize(id:, public_key:, sign_count:, aaguid: nil, relying_party_id: nil, backed_up: nil, transports: []) # :nodoc:
        @id = id
        @public_key = public_key
        @public_key = OpenSSL::PKey.read(public_key) unless public_key.is_a?(OpenSSL::PKey::PKey)
        @sign_count = sign_count
        @aaguid = aaguid
        @relying_party_id = relying_party_id
        @backed_up = backed_up
        @transports = transports
      end

      # Verifies an assertion response against this credential's public key.
      # Updates +sign_count+ and +backed_up+ on success.
      #
      # Raises +InvalidResponseError+ if the assertion is invalid.
      def authenticate(params, origin: ActionPack::WebAuthn::Current.origin)
        response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
          client_data_json: params[:client_data_json],
          authenticator_data: params[:authenticator_data],
          signature: params[:signature],
          credential: self,
          origin: origin
        )

        response.validate!

        @sign_count = response.authenticator_data.sign_count
        @backed_up = response.authenticator_data.backed_up?
      end

      # Returns a Hash of the credential data suitable for persisting.
      def to_h
        {
          credential_id: id,
          public_key: public_key.to_der,
          sign_count: sign_count,
          aaguid: aaguid,
          relying_party_id: relying_party_id,
          backed_up: backed_up,
          transports: transports
        }
      end
    end
  end
end
