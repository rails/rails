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
      end

      def method_missing(name, *args, &block)
        @tempfile.send(name, *args, &block)
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
