module ActionDispatch
  module Http
    # Models uploaded files.
    #
    # The actual file is accessible via the +tempfile+ accessor, though some
    # of its interface is available directly for convenience.
    #
    # Uploaded files are temporary files whose lifespan is one request. When
    # the object is finalized Ruby unlinks the file, so there is not need to
    # clean them with a separate maintenance task.
    class UploadedFile
      # The basename of the file in the client.
      attr_accessor :original_filename

      # A string with the MIME type of the file.
      attr_accessor :content_type

      # A +Tempfile+ object with the actual uploaded file. Note that some of
      # its interface is available directly.
      attr_accessor :tempfile

      # A string with the headers of the multipart request.
      attr_accessor :headers

      def initialize(hash) # :nodoc:
        @tempfile          = hash[:tempfile]
        raise(ArgumentError, ':tempfile is required') unless @tempfile

        @original_filename = encode_filename(hash[:filename])
        @content_type      = hash[:type]
        @headers           = hash[:head]
      end

      # Shortcut for +tempfile.read+.
      def read(length=nil, buffer=nil)
        @tempfile.read(length, buffer)
      end

      # Shortcut for +tempfile.open+.
      def open
        @tempfile.open
      end

      # Shortcut for +tempfile.close+.
      def close(unlink_now=false)
        @tempfile.close(unlink_now)
      end

      # Shortcut for +tempfile.path+.
      def path
        @tempfile.path
      end

      # Shortcut for +tempfile.rewind+.
      def rewind
        @tempfile.rewind
      end

      # Shortcut for +tempfile.size+.
      def size
        @tempfile.size
      end

      # Shortcut for +tempfile.eof?+.
      def eof?
        @tempfile.eof?
      end

      private

      def encode_filename(filename)
        # Encode the filename in the utf8 encoding, unless it is nil
        filename.force_encoding("UTF-8").encode! if filename
      end
    end

    module Upload # :nodoc:
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
