module ActionController
  class AbstractResponse #:nodoc:
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache" }
    attr_accessor :body, :headers, :session, :cookies, :assigns, :template, :redirected_to, :redirected_to_method_params

    def initialize
      @body, @headers, @session, @assigns = "", DEFAULT_HEADERS.merge("cookie" => []), [], []
    end

    def redirect(to_url, permanently = false)
      @headers["Status"]   = permanently ? "301 Moved Permanently" : "302 Found"
      @headers["location"] = to_url
    end
  end
end