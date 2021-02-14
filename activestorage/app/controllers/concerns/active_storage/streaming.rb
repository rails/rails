# frozen_string_literal: true

module ActiveStorage::Streaming
  private
    # Stream the blob from storage directly to the response. The disposition can be controlled by setting +disposition+.
    # The content type and filename is set directly from the +blob+.
    def stream_from_storage(blob, disposition: nil) # :doc:
      response.headers["Content-Type"] = blob.content_type_for_serving
      response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format \
        disposition: blob.forced_disposition_for_serving || params[:disposition] || disposition || "inline", 
        filename: blob.filename.sanitized

      blob.download do |chunk|
        response.stream.write chunk
      end
    ensure
      response.stream.close
    end
end
