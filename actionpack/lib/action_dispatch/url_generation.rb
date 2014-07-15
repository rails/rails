module ActionDispatch
  module UrlGeneration # :nodoc:
    def self.request(request, options)
      RequestContext.new request, options
    end

    def self.empty(options)
      Context.new({}, options)
    end

    def self.null; NULL; end

    # :nodoc:
    Context = Struct.new :path_parameters, :url_options

    NULL = empty({})

    class RequestContext # :nodoc:
      attr_reader :url_options

      def initialize(request, options)
        @request     = request
        @url_options = options
      end

      def path_parameters
        @request.path_parameters
      end
    end
  end
end
