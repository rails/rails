# frozen_string_literal: true

module ActionPack
  module WebAuthn
    module Authenticator
      module AttestationVerifiers
        # = Action Pack WebAuthn None Attestation Verifier
        #
        # Verifies attestation responses with the "none" format, which indicates the
        # authenticator did not provide any attestation statement. This is the default
        # format used by most consumer authenticators.
        #
        # == Implementing Custom Verifiers
        #
        # To support other attestation formats (e.g., "packed", "fido-u2f"), implement
        # a class with the same +verify!+ interface and register it:
        #
        #   ActionPack::WebAuthn.register_attestation_verifier("packed", MyPackedVerifier.new)
        #
        # The +verify!+ method receives the decoded +Attestation+ object and the raw
        # +client_data_json+ bytes. Raise +InvalidResponseError+ if verification fails.
        #
        class None
          def verify!(attestation, client_data_json:)
            if attestation.attestation_statement.present?
              raise ActionPack::WebAuthn::InvalidResponseError,
                "Attestation statement must be empty for 'none' format"
            end
          end
        end
      end
    end
  end
end
