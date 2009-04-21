require 'rack/utils'

module Rack

  # Middleware that enables conditional GET using If-None-Match and
  # If-Modified-Since. The application should set either or both of the
  # Last-Modified or Etag response headers according to RFC 2616. When
  # either of the conditions is met, the response body is set to be zero
  # length and the response status is set to 304 Not Modified.
  #
  # Applications that defer response body generation until the body's each
  # message is received will avoid response body generation completely when
  # a conditional GET matches.
  #
  # Adapted from Michael Klishin's Merb implementation:
  # http://github.com/wycats/merb-core/tree/master/lib/merb-core/rack/middleware/conditional_get.rb
  class ConditionalGet
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless %w[GET HEAD].include?(env['REQUEST_METHOD'])

      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)
      if etag_matches?(env, headers) || modified_since?(env, headers)
        status = 304
        body = []
      end
      [status, headers, body]
    end

  private
    def etag_matches?(env, headers)
      etag = headers['Etag'] and etag == env['HTTP_IF_NONE_MATCH']
    end

    def modified_since?(env, headers)
      last_modified = headers['Last-Modified'] and
        last_modified == env['HTTP_IF_MODIFIED_SINCE']
    end
  end

end
