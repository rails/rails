# frozen_string_literal: true

class ActiveStorage::Checksum # :nodoc:
  require "openssl"

  attr_reader :digest, :algorithm

  @md5_class    = nil
  @crc32_class  = nil
  @crc32c_class = nil
  @crc64_class  = nil
  @crc64nvme_class  = nil

  SUPPORTED_CHECKSUMS = [
    :MD5,
    :CRC32,
    :CRC32c,
    :CRC64,
    :SHA1,
    :SHA256,
    :CRC64NVMe
  ]

  def initialize(digest, algorithm = nil)
    @digest, @algorithm = digest, algorithm || :MD5
  end

  def ==(other)
    return super unless other.is_a?(ActiveStorage::Checksum)
    digest == other.digest && algorithm == other.algorithm
  end

  def to_s
    self.class.dump(self)
  end

  class << self
    def load(checksum)
      # checksum is string in format of "<algorithm>:<digest>" like "SHA256:<SHA256Hash>"
      # or legacy case "<MD5hash>"

      unless checksum.blank?
        algorithm, digest = checksum.split(":", 2)
        unless digest
          # if no ":" to split on, checksum is MD5 digest
          digest = algorithm
          algorithm = :MD5
        end

        new(digest, algorithm.to_sym)
      end
    end

    def dump(checksum)
      return unless checksum

      # preserve legacy data format for MD5
      return checksum.digest if checksum.algorithm == :MD5

      "#{checksum.algorithm}:#{checksum.digest}" if checksum
    end

    def implementation_class(checksum_algorithm)
      send(checksum_algorithm.downcase) if SUPPORTED_CHECKSUMS.include?(checksum_algorithm)
    end

    def file(file, algorithm)
      new(implementation_class(algorithm).file(file).base64digest, algorithm)
    end

    def base64digest(io, algorithm)
      new(implementation_class(algorithm).base64digest(io), algorithm)
    end

    def compute_checksum_in_chunks(io, service)
      raise ArgumentError, "io must be rewindable" unless io.respond_to?(:rewind)
      return unless service

      new(implementation_class(service.checksum_algorithm).new.tap do |checksum|
          read_buffer = "".b
          while io.read(5.megabytes, read_buffer)
            checksum << read_buffer
          end

          io.rewind
        end.base64digest, service.checksum_algorithm)
    end

    def md5
      return @md5_class if @md5_class
      @md5_class = OpenSSL::Digest::MD5
      @md5_class.hexdigest("test")
      OpenSSL::Digest::MD5
    rescue # OpenSSL may have MD5 disabled
      require "digest/md5"
      @md5_class = Digest::MD5
    end

    def sha1
      OpenSSL::Digest::SHA1
    end

    def sha256
      OpenSSL::Digest::SHA256
    end

    def crc32
      return @crc32_class if @crc32_class
      begin
        require "digest/crc32"
      rescue LoadError
        raise LoadError, 'digest/crc32 not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc32_class = Digest::CRC32
    end

    def crc32c
      return @crc32c_class if @crc32c_class
      begin
        require "digest/crc32c"
      rescue LoadError
        raise LoadError, 'digest/crc32c not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc32c_class = Digest::CRC32c
    end

    def crc64
      return @crc64_class if @crc64_class
      begin
        require "digest/crc64"
      rescue LoadError
        raise LoadError, 'digest/crc64 not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc64_class = Digest::CRC64
    end

    def crc64nvme
      return @crc64nvme_class if @crc64nvme_class
      begin
        require "digest/crc64nvme"
      rescue LoadError
        raise LoadError, 'digest/crc64nvme not loaded. Please add `gem "digest-crc"` to your gemfile.'
      end
      @crc64nvme_class = Digest::CRC64NVMe
    end
  end
end
