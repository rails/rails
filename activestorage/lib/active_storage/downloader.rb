# frozen_string_literal: true

module ActiveStorage
  class Downloader # :nodoc:
    attr_reader :service

    def initialize(service)
      @service = service
    end

    def open(key, checksum: nil, verify: true, name: "ActiveStorage-", tmpdir: nil)
      if block_given?
        Tempfile.open(name, tmpdir, binmode: true) do |file|
          download(key, file)
          verify_integrity_of(file, checksum: checksum) if verify
          yield file
        end
      else
        file = Tempfile.new(name, tmpdir, binmode: true)
        download(key, file)
        verify_integrity_of(file, checksum: checksum) if verify
        file
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
