# frozen_string_literal: true

module ActiveStorage
  class Downloader #:nodoc:
    def initialize(blob, tempdir: nil)
      @blob    = blob
      @tempdir = tempdir
    end

    def download_blob_to_tempfile
      open_tempfile do |file|
        download_blob_to file
        verify_integrity_of file
        yield file
      end
    end

    private
      attr_reader :blob, :tempdir

      def open_tempfile
        file = Tempfile.open([ "ActiveStorage", tempfile_extension_with_delimiter ], tempdir)

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

      def verify_integrity_of(file)
        unless Digest::MD5.file(file).base64digest == checksum
          raise ActiveStorage::IntegrityError
        end
      end

      def tempfile_extension_with_delimiter
        blob.filename.extension_with_delimiter
      end
  end
end
