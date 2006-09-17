module ActionController
  class AbstractResponse #:nodoc:
    DEFAULT_HEADERS = { "Cache-Control" => "no-cache" }
    attr_accessor :body, :headers, :session, :cookies, :assigns, :template, :redirected_to, :redirected_to_method_params, :layout

    def initialize
      @body, @headers, @session, @assigns = "", DEFAULT_HEADERS.merge("cookie" => []), [], []
    end

    def content_type=(mime_type)
      @headers["Content-Type"] = charset ? "#{mime_type}; charset=#{charset}" : mime_type
    end
    
    def content_type
      content_type = String(@headers["Content-Type"]).split(";")[0]
      content_type.blank? ? nil : content_type
    end
    
    def charset=(encoding)
      @headers["Content-Type"] = "#{content_type || "text/html"}; charset=#{encoding}"
    end
    
    def charset
      charset = String(@headers["Content-Type"]).split(";")[1]
      charset.blank? ? nil : charset.strip.split("=")[1]
    end

    def redirect(to_url, permanently = false)
      @headers["Status"]   = "302 Found" unless @headers["Status"] == "301 Moved Permanently"
      @headers["location"] = to_url

      @body = "<html><body>You are being <a href=\"#{to_url}\">redirected</a>.</body></html>"
    end
  end
end