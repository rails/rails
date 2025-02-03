# frozen_string_literal: true

class ActiveStorage::Checksum # :nodoc:
  attr_reader :digest, :algorithm
  SUPPORTED_CHECKSUMS = [:MD5]
  @md5_class    = nil

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
      if checksum.algorithm == :MD5
        checksum.digest
      else
        "#{checksum.algorithm}:#{checksum.digest}"
      end
    end
  end
end
