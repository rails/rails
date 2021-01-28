# frozen_string_literal: true

module ActiveStorage
  module DirectUploadToken
    SEPARATOR = "."

    module_function

    def generate_direct_upload_token(attachment_name, service_name, session)
      token = per_attachment_direct_upload_token(session, attachment_name)
      encode_csrf_token([service_name, token].join(SEPARATOR))
    end

    def verify_direct_upload_token(token, attachment_name, session)
      return if token.nil?

      service_name, csrf_token = decode_csrf_token(token).split(SEPARATOR)
      return service_name if valid_per_attachment_token?(csrf_token, attachment_name, session)

      raise ActiveStorage::WrongDirectUploadTokenError
    end

    def valid_per_attachment_token?(token, attachment_name, session) # :doc:
      correct_token = per_attachment_direct_upload_token(session, attachment_name)
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, correct_token)
    rescue ArgumentError
      raise ActiveStorage::WrongDirectUploadTokenError
    end

    def per_attachment_direct_upload_token(session, attachment_name) # :doc:
      direct_upload_token_hmac(session, "direct_upload##{attachment_name}")
    end

    def direct_upload_token_hmac(session, identifier) # :doc:
      OpenSSL::HMAC.digest(
        OpenSSL::Digest::SHA256.new,
        real_direct_upload_token(session),
        identifier
      )
    end

    DIRECT_UPLOAD_TOKEN_LENGTH = 32

    def real_direct_upload_token(session) # :doc:
      session[:_direct_upload_token] ||= SecureRandom.urlsafe_base64(DIRECT_UPLOAD_TOKEN_LENGTH, padding: false)
      encode_csrf_token(session[:_direct_upload_token])
    end

    def decode_csrf_token(encoded_token) # :nodoc:
      Base64.urlsafe_decode64(encoded_token)
    end

    def encode_csrf_token(raw_token) # :nodoc:
      Base64.urlsafe_encode64(raw_token)
    end
  end
end
