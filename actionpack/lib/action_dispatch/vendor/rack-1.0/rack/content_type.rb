require 'rack/utils'

module Rack

  # Sets the Content-Type header on responses which don't have one.
  #
  # Builder Usage:
  #   use Rack::ContentType, "text/plain"
  #
  # When no content type argument is provided, "text/html" is assumed.
  class ContentType
    def initialize(app, content_type = "text/html")
      @app, @content_type = app, content_type
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)
      headers['Content-Type'] ||= @content_type
      [status, headers.to_hash, body]
    end
  end
end
