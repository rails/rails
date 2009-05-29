require 'rack/utils'

module Rack
  # Sets the Content-Length header on responses with fixed-length bodies.
  class ContentLength
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = HeaderHash.new(headers)

      if !STATUS_WITH_NO_ENTITY_BODY.include?(status) &&
         !headers['Content-Length'] &&
         !headers['Transfer-Encoding'] &&
         (body.respond_to?(:to_ary) || body.respond_to?(:to_str))

        body = [body] if body.respond_to?(:to_str) # rack 0.4 compat
        length = body.to_ary.inject(0) { |len, part| len + bytesize(part) }
        headers['Content-Length'] = length.to_s
      end

      [status, headers, body]
    end
  end
end
