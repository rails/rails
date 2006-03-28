module ActionController
  class Base
    protected
      # Deprecated in favor of calling redirect_to directly with the path.
      def redirect_to_path(path) #:nodoc:
        redirect_to(path)
      end

      # Deprecated in favor of calling redirect_to directly with the url. If the resource has moved permanently, it's possible to pass
      # true as the second parameter and the browser will get "301 Moved Permanently" instead of "302 Found". This can also be done through
      # just setting the headers["Status"] to "301 Moved Permanently" before using the redirect_to.
      def redirect_to_url(url, permanently = false) #:nodoc:
        headers["Status"] = "301 Moved Permanently" if permanently
        redirect_to(url)
      end
  end
end
