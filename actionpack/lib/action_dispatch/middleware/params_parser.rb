require "action_dispatch/http/request"

module ActionDispatch
  # ActionDispatch::ParamsParser works for all the requests having any Content-Length
  # (like POST). It takes raw data from the request and puts it through the parser
  # that is picked based on Content-Type header.
  #
  # In case of any error while parsing data ParamsParser::ParseError is raised.
  module ParamsParser
    # Raised when raw data from the request cannot be parsed by the parser
    # defined for request's content mime type.
    class ParseError < StandardError
      def initialize
        super($!.message)
      end
    end
  end
end
