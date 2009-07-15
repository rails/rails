require 'thor/actions/templater'

class Thor
  module Actions

    # Create a new file relative to the destination root with the given data,
    # which is the return value of a block or a data string.
    #
    # ==== Parameters
    # destination<String>:: the relative path to the destination root.
    # data<String|NilClass>:: the data to append to the file.
    # config<Hash>:: give :verbose => false to not log the status.
    #
    # ==== Examples
    #
    #   create_file "lib/fun_party.rb" do
    #     hostname = ask("What is the virtual hostname I should use?")
    #     "vhost.name = #{hostname}"
    #   end
    #
    #   create_file "config/apach.conf", "your apache config"
    #
    def create_file(destination, data=nil, config={}, &block)
      action CreateFile.new(self, destination, block || data.to_s, config)
    end
    alias :add_file :create_file

    # AddFile is a subset of Template, which instead of rendering a file with
    # ERB, it gets the content from the user.
    #
    class CreateFile < Templater #:nodoc:
      attr_reader :data

      def initialize(base, destination, data, config={})
        super(base, nil, destination, config)
        @data = data
      end

      def render
        @render ||= if data.is_a?(Proc)
          data.call
        else
          data
        end
      end

    end
  end
end
