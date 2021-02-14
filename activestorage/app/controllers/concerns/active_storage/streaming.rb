# frozen_string_literal: true

module ActiveStorage::Streaming
  private

  # Stream the blob from storage directly to the response.
  def stream_from_storage(blob)
    blob.download do |chunk|
      response.stream.write chunk
    end
  ensure
    response.stream.close
  end
end
