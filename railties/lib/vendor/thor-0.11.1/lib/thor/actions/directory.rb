require 'thor/actions/templater'

class Thor
  module Actions

    # Copies interactively the files from source directory to root directory.
    # If any of the files finishes with .tt, it's considered to be a template
    # and is placed in the destination without the extension .tt. If any
    # empty directory is found, it's copied and all .empty_directory files are
    # ignored. Remember that file paths can also be encoded, let's suppose a doc
    # directory with the following files:
    #
    #   doc/
    #     components/.empty_directory
    #     README
    #     rdoc.rb.tt
    #     %app_name%.rb
    #
    # When invoked as:
    #
    #   directory "doc"
    #
    # It will create a doc directory in the destination with the following
    # files (assuming that the app_name is "blog"):
    #
    #   doc/
    #     components/
    #     README
    #     rdoc.rb
    #     blog.rb
    #
    # ==== Parameters
    # source<String>:: the relative path to the source root
    # destination<String>:: the relative path to the destination root
    # recursive<Boolean>:: if the directory must be copied recursively, true by default
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #
    # ==== Examples
    #
    #   directory "doc"
    #   directory "doc", "docs", false
    #
    def directory(source, destination=nil, recursive=true, log_status=true)
      action Directory.new(self, source, destination || source, recursive, log_status)
    end

    class Directory < Templater #:nodoc:
      attr_reader :recursive

      def initialize(base, source, destination=nil, recursive=true, log_status=true)
        @recursive = recursive
        super(base, source, destination, log_status)
      end

      def invoke!
        base.empty_directory given_destination, @log_status
        execute!
      end

      def revoke!
        execute!
      end

      protected

        def execute!
          lookup = recursive ? File.join(source, '**') : source
          lookup = File.join(lookup, '{*,.[a-z]*}')

          Dir[lookup].each do |file_source|
            next if File.directory?(file_source)
            file_destination = File.join(given_destination, file_source.gsub(source, '.'))

            case file_source
              when /\.empty_directory$/
                base.empty_directory(File.dirname(file_destination), @log_status)
              when /\.tt$/
                base.template(file_source, file_destination[0..-4], @log_status)
              else
                base.copy_file(file_source, file_destination, @log_status)
            end
          end
        end

    end
  end
end
