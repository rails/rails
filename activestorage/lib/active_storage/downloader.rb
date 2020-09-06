# frozen_string_literal: true

module ActiveStorage
  class Downloader #:nodoc:
    attr_reader :service

    def initialize(service)
      @service = service
    end

    def open(key, checksum:, name: 'ActiveStorage-', tmpdir: nil)
      open_tempfile(name, tmpdir) do |file|
        download key, file
        verify_integrity_of file, checksum: checksum
        yield file
      end
    end

    private
      def open_tempfile(name, tmpdir = nil)
        file = Tempfile.open(name, tmpdir)

        begin
          yield file
        ensure
          file.close!
        end
      end

      def download(key, file)
        file.binmode
        service.download(key) { |chunk| file.write(chunk) }
        file.flush
        file.rewind
      end

      def verify_integrity_of(file, checksum:)
        unless Digest::MD5.file(file).base64digest == checksum
          raise ActiveStorage::IntegrityError
        end
      end
  end
end
