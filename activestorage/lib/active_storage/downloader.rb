# frozen_string_literal: true

module ActiveStorage
  class Downloader # :nodoc:
    attr_reader :service

    def initialize(service)
      @service = service
    end

    def open(key, checksum: nil, verify: true, name: "ActiveStorage-", tmpdir: nil, &block)
      tempfile = Tempfile.new(name, tmpdir, binmode: true)
      download(key, tempfile)
      verify_integrity_of(tempfile, checksum: checksum) if verify

      if block_given?
        begin
          yield tempfile
        ensure
          tempfile.close!
        end
      else
        tempfile
      end
    end

    private
      def download(key, file)
        service.download(key) { |chunk| file.write(chunk) }
        file.flush
        file.rewind
      end

      def verify_integrity_of(file, checksum:)
        unless OpenSSL::Digest::MD5.file(file).base64digest == checksum
          raise ActiveStorage::IntegrityError
        end
      end
  end
end
