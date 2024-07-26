module ActionController
  class Response #:nodoc:
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache", "cookie" => [] }
    attr_accessor :body, :headers, :session, :cookies, :assigns, :template

    def initialize
      @body, @headers, @session, @assigns = "", DEFAULT_HEADERS.dup, [], []
    end

    def redirect(to_url)
      @headers["Status"]   = "302 Moved"
      @headers["location"] = to_url
    end
  end
end