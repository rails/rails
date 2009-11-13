module ActionController
  module UploadedFile
    def self.included(base)
      base.class_eval do
        attr_accessor :original_path, :content_type
        alias_method :local_path, :path if method_defined?(:path)
      end
    end

    def self.extended(object)
      object.class_eval do
        attr_accessor :original_path, :content_type
        alias_method :local_path, :path if method_defined?(:path)
      end
    end

    # Take the basename of the upload's original filename.
    # This handles the full Windows paths given by Internet Explorer
    # (and perhaps other broken user agents) without affecting
    # those which give the lone filename.
    # The Windows regexp is adapted from Perl's File::Basename.
    def original_filename
      unless defined? @original_filename
        @original_filename =
          unless original_path.blank?
            if original_path =~ /^(?:.*[:\\\/])?(.*)/m
              $1
            else
              File.basename original_path
            end
          end
      end
      @original_filename
    end
  end

  class UploadedStringIO < StringIO
    include UploadedFile
  end

  class UploadedTempfile < Tempfile
    include UploadedFile
  end
end
