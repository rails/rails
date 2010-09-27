require 'uri'

module ActionController #:nodoc:
  module UriParser
    def uri_parser
      @uri_parser ||= URI.const_defined?(:Parser) ? URI::Parser.new : URI
    end
  end
end
