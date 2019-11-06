# frozen_string_literal: true

module ActiveStorage::SetHeaders #:nodoc:
  extend ActiveSupport::Concern

  private
    def set_headers

    end

    def disposition(blob, disposition_override = nil)
      ActionDispatch::Http::ContentDisposition.format(
        disposition: disposition_override || "inline",
        filename: blob.filename.sanitized
      )
    end
end
