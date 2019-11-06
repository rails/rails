# frozen_string_literal: true

module ActiveStorage::SetHeaders #:nodoc:
  extend ActiveSupport::Concern

  private
    def set_headers(blob)
      expires_in ActiveStorage.proxy_urls_expire_in, public: true

      response.headers["Content-Type"] = blob.content_type
      response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
        disposition: params[:disposition] || "inline",
        filename: blob.filename.sanitized
      )
    end
end
