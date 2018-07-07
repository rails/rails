# frozen_string_literal: true

module ActiveStorage
  # Generate the blob key according to blob key_format.
  #
  # Example
  #   blob.filename.to_s
  #   # => "example.png"
  #   blob.key_format
  #   # => "/avatars/:hash/:filename.:extension"
  #
  #   ActiveStorage::BlobKeyGenerator.new(blob).generate
  #   # => "/avatars/2vAjTGganF63Uri3TjBwunbM/example.png"
  class BlobKeyGenerator
    def initialize(blob)
      @blob = blob
      @key_format = blob.key_format
    end

    def generate
      key_format.scan(/:\w+/).reduce(key_format) do |pattern, token|
        pattern.sub(token, convert_token(token))
      end
    end

    private
      attr_reader :blob, :key_format

      def convert_token(token)
        case token
        when ":hash"
          blob.class.generate_unique_secure_token
        when ":filename"
          blob.filename.base
        when ":extension"
          blob.filename.extension_without_delimiter
        else
          raise InvalidKeyTokenError, "Invalid token for key_format: #{token}"
        end
      end
  end
end
