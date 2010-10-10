require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Http
    class UploadedFile
      attr_accessor :original_filename, :content_type, :tempfile, :headers

      def initialize(hash)
        @original_filename = hash[:filename]
        @content_type      = hash[:type]
        @headers           = hash[:head]
        @tempfile          = hash[:tempfile]
        raise(ArgumentError, ':tempfile is required') unless @tempfile
      end

      def read(*args)
        @tempfile.read(*args)
      end

      def rewind
        @tempfile.rewind
      end

      def size
        @tempfile.size
      end
    end

    module Upload
      # Convert nested Hash to HashWithIndifferentAccess and replace
      # file upload hash with UploadedFile objects
      def normalize_parameters(value)
        if Hash === value && value.has_key?(:tempfile)
          UploadedFile.new(value)
        else
          super
        end
      end
      private :normalize_parameters
    end
  end
end
