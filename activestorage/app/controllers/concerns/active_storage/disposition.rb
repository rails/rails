# frozen_string_literal: true

module ActiveStorage::Disposition #:nodoc:
  extend ActiveSupport::Concern

  private
    def disposition(blob, disposition_override = nil)
      ActionDispatch::Http::ContentDisposition.format(
        disposition: disposition_override || "inline",
        filename: blob.filename.sanitized
      )
    end
end
