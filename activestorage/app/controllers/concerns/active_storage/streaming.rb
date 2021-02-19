# frozen_string_literal: true

module ActiveStorage::Streaming
  DEFAULT_BLOB_STREAMING_DISPOSITION = "inline"

  include ActionController::Live

  private
    # Stream the blob from storage directly to the response. The disposition can be controlled by setting +disposition+.
    # The content type and filename is set directly from the +blob+.
    def send_blob_stream(blob, disposition: nil)
      send_stream(
          filename: blob.filename.sanitized,
          disposition: blob.forced_disposition_for_serving || disposition || DEFAULT_BLOB_STREAMING_DISPOSITION,
          type: blob.content_type_for_serving) do |stream|
        blob.download do |chunk|
          stream.write chunk
        end
      end
    end
end
