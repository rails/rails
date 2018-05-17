# frozen_string_literal: true

module ActiveStorage
  class Downloader
    def initialize(blob)
      @blob = blob
    end

    def download_blob_to_tempfile
      open_tempfile do |file|
        download_blob_to file
        yield file
      end
    end

    private
      attr_reader :blob

      def open_tempfile
        file = Tempfile.open([ "ActiveStorage", tempfile_extension_with_delimiter ])

        begin
          yield file
        ensure
          file.close!
        end
      end

      def download_blob_to(file)
        file.binmode
        blob.download { |chunk| file.write(chunk) }
        file.flush
        file.rewind
      end

      def tempfile_extension_with_delimiter
        blob.filename.extension_with_delimiter
      end
  end
end
