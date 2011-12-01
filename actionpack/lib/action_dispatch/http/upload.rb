module ActionDispatch
  module Http
    class UploadedFile
      attr_accessor :original_filename, :content_type, :tempfile, :headers

      def initialize(hash)
        @original_filename = encode_filename(hash[:filename])
        @content_type      = hash[:type]
        @headers           = hash[:head]
        @tempfile          = hash[:tempfile]
        raise(ArgumentError, ':tempfile is required') unless @tempfile
      end

      def read(*args)
        @tempfile.read(*args)
      end

      # Delegate these methods to the tempfile.
      [:open, :path, :rewind, :size].each do |method|
        class_eval "def #{method}; @tempfile.#{method}; end"
      end
      
      private
      def encode_filename(filename)
        # Encode the filename in the utf8 encoding, unless it is nil or we're in 1.8
        if "ruby".encoding_aware? && filename
          filename.force_encoding("UTF-8").encode!
        else
          filename
        end
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
