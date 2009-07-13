require 'thor/actions/templater'
require 'open-uri'

class Thor
  module Actions

    # Gets the content at the given address and places it at the given relative
    # destination. If a block is given instead of destination, the content of
    # the url is yielded and used as location.
    #
    # ==== Parameters
    # source<String>:: the address of the given content
    # destination<String>:: the relative path to the destination root
    # log_status<Boolean>:: if false, does not log the status. True by default.
    #
    # ==== Examples
    #
    #   get "http://gist.github.com/103208", "doc/README"
    #
    #   get "http://gist.github.com/103208" do |content|
    #     content.split("\n").first
    #   end
    #
    def get(source, destination=nil, log_status=true, &block)
      action Get.new(self, source, block || destination, log_status)
    end

    class Get < Templater #:nodoc:

      def render
        @render ||= open(source).read
      end

      protected

        def source=(source)
          if source =~ /^http\:\/\//
            @source = source
          else
            super(source)
          end
        end

        def destination=(destination)
          destination = if destination.nil?
            File.basename(source)
          elsif destination.is_a?(Proc)
            destination.arity == 1 ? destination.call(render) : destination.call
          else
            destination
          end

          super(destination)
        end

    end
  end
end
