module ActionController
  class AbstractResponse #:nodoc:
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache" }
    attr_accessor :body, :headers, :session, :cookies, :assigns, :template, :redirected_to, :redirected_to_method_params

    def initialize
      @body, @headers, @session, @assigns = "", DEFAULT_HEADERS.merge("cookie" => []), [], []
    end

    def redirect(to_url)
      @headers["Status"]   = "302 Moved"
      @headers["location"] = to_url
    end
  end
end