# frozen_string_literal: true

module ActiveStorage
  module DirectUploadToken
    extend self

    SEPARATOR = "."
    DIRECT_UPLOAD_TOKEN_LENGTH = 32

    def generate_direct_upload_token(attachment_name, service_name, session)
      token = direct_upload_token(session, attachment_name)
      encode_direct_upload_token([service_name, token].join(SEPARATOR))
    end

    def verify_direct_upload_token(token, attachment_name, session)
      raise ActiveStorage::InvalidDirectUploadTokenError if token.nil?

      service_name, *token_components = decode_token(token).split(SEPARATOR)
      decoded_token = token_components.join(SEPARATOR)

      return service_name if valid_direct_upload_token?(decoded_token, attachment_name, session)

      raise ActiveStorage::InvalidDirectUploadTokenError
    end

    private
      def direct_upload_token(session, attachment_name) # :doc:
        direct_upload_token_hmac(session, "direct_upload##{attachment_name}")
      end

      def valid_direct_upload_token?(token, attachment_name, session) # :doc:
        correct_token = direct_upload_token(session, attachment_name)
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, correct_token)
      rescue ArgumentError
        raise ActiveStorage::InvalidDirectUploadTokenError
      end

      def direct_upload_token_hmac(session, identifier) # :doc:
        OpenSSL::HMAC.digest(
          OpenSSL::Digest::SHA256.new,
          real_direct_upload_token(session),
          identifier
        )
      end

      def real_direct_upload_token(session) # :doc:
        session[:_direct_upload_token] ||= SecureRandom.urlsafe_base64(DIRECT_UPLOAD_TOKEN_LENGTH, padding: false)
        encode_direct_upload_token(session[:_direct_upload_token])
      end

      def decode_token(encoded_token) # :nodoc:
        Base64.urlsafe_decode64(encoded_token)
      end

      def encode_direct_upload_token(raw_token) # :nodoc:
        Base64.urlsafe_encode64(raw_token)
      end
  end
end
