require 'thor/actions/templater'

class Thor
  module Actions

    # Creates an empty directory.
    #
    # ==== Parameters
    # destination<String>:: the relative path to the destination root.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   empty_directory "doc"
    #
    def empty_directory(destination, config={})
      action EmptyDirectory.new(self, nil, destination, config)
    end

    class EmptyDirectory < Templater #:nodoc:

      def invoke!
        invoke_with_options!(base.options.merge(config)) do
          ::FileUtils.mkdir_p(destination)
        end
      end

    end
  end
end
