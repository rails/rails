# frozen_string_literal: true

module ActiveStorage
  module Downloading
    private
      # Opens a new tempfile and copies blob data into it. Yields the tempfile.
      def download_blob_to_tempfile # :doc:
        Tempfile.open("ActiveStorage") do |file|
          download_blob_to file
          yield file
        end
      end

      # Efficiently download blob data into the given file.
      def download_blob_to(file) # :doc:
        file.binmode
        blob.download { |chunk| file.write(chunk) }
        file.rewind
      end
  end
end
