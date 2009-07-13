require 'thor/actions/templater'

class Thor
  module Actions

    # Creates an empty directory.
    #
    # ==== Parameters
    # destination<String>:: the relative path to the destination root
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #
    # ==== Examples
    #
    #   empty_directory "doc"
    #
    def empty_directory(destination, log_status=true)
      action EmptyDirectory.new(self, nil, destination, log_status)
    end

    class EmptyDirectory < Templater #:nodoc:

      def invoke!
        invoke_with_options!(base.options) do
          ::FileUtils.mkdir_p(destination)
        end
      end

    end
  end
end
