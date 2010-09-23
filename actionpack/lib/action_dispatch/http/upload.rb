require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Http
    class UploadedFile < Tempfile
      attr_accessor :original_filename, :content_type, :tempfile, :headers

      def initialize(hash)
        @original_filename = hash[:filename]
        @content_type      = hash[:type]
        @headers           = hash[:head]

        # To the untrained eye, this may appear as insanity. Given the alternatives,
        # such as busting the method cache on every request or breaking backwards
        # compatibility with is_a?(Tempfile), this solution is the best available
        # option.
        #
        # TODO: Deprecate is_a?(Tempfile) and define a real API for this parameter
        tempfile = hash[:tempfile]
        tempfile.instance_variables.each do |ivar|
          instance_variable_set(ivar, tempfile.instance_variable_get(ivar))
        end
      end

      alias local_path path
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
