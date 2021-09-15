# frozen_string_literal: true

require "securerandom"

module ActiveStorage::Streaming
  DEFAULT_BLOB_STREAMING_DISPOSITION = "inline"

  include ActionController::DataStreaming
  include ActionController::Live

  private
    # Stream the blob in byte ranges specified through the header
    def send_blob_byte_range_data(blob, range_header, disposition: nil)
      ranges = Rack::Utils.get_byte_ranges(range_header, blob.byte_size)

      return head(:range_not_satisfiable) if ranges.blank? || ranges.all?(&:blank?)

      if ranges.length == 1
        range = ranges.first
        content_type = blob.content_type_for_serving
        data = blob.download_chunk(range)

        response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{blob.byte_size}"
      else
        boundary = SecureRandom.hex
        content_type = "multipart/byteranges; boundary=#{boundary}"
        data = +""

        ranges.compact.each do |range|
          chunk = blob.download_chunk(range)

          data << "\r\n--#{boundary}\r\n"
          data << "Content-Type: #{blob.content_type_for_serving}\r\n"
          data << "Content-Range: bytes #{range.begin}-#{range.end}/#{blob.byte_size}\r\n\r\n"
          data << chunk
        end

        data << "\r\n--#{boundary}--\r\n"
      end

      response.headers["Accept-Ranges"] = "bytes"
      response.headers["Content-Length"] = data.length.to_s

      send_data(
        data,
        disposition: blob.forced_disposition_for_serving || disposition || DEFAULT_BLOB_STREAMING_DISPOSITION,
        filename: blob.filename.sanitized,
        status: :partial_content,
        type: content_type
      )
    end

    # Stream the blob from storage directly to the response. The disposition can be controlled by setting +disposition+.
    # The content type and filename is set directly from the +blob+.
    def send_blob_stream(blob, disposition: nil) # :doc:
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
