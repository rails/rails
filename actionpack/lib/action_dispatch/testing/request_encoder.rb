module ActionDispatch
  class RequestEncoder # :nodoc:
    class IdentityEncoder
      def content_type; end
      def accept_header; end
      def encode_params(params); params; end
      def response_parser; -> body { body }; end
    end

    @encoders = { identity: IdentityEncoder.new }

    attr_reader :response_parser

    def initialize(mime_name, param_encoder, response_parser)
      @mime = Mime[mime_name]

      unless @mime
        raise ArgumentError, "Can't register a request encoder for " \
          "unregistered MIME Type: #{mime_name}. See `Mime::Type.register`."
      end

      @response_parser = response_parser || -> body { body }
      @param_encoder   = param_encoder   || :"to_#{@mime.symbol}".to_proc
    end

    def content_type
      @mime.to_s
    end

    def accept_header
      @mime.to_s
    end

    def encode_params(params)
      @param_encoder.call(params)
    end

    def self.parser(content_type)
      mime = Mime::Type.lookup(content_type)
      encoder(mime ? mime.ref : nil).response_parser
    end

    def self.encoder(name)
      @encoders[name] || @encoders[:identity]
    end

    def self.register_encoder(mime_name, param_encoder: nil, response_parser: nil)
      @encoders[mime_name] = new(mime_name, param_encoder, response_parser)
    end

    register_encoder :json, response_parser: -> body { JSON.parse(body) }
  end
end
