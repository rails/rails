module ActionController
  class RedirectBackError < AbstractController::Error #:nodoc:
    DEFAULT_MESSAGE = 'No HTTP_REFERER was set in the request to this action, so redirect_to :back could not be called successfully. If this is a test, make sure to specify request.env["HTTP_REFERER"].'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  module Redirector
    def redirect_to(url, status) #:doc:
      raise AbstractController::DoubleRenderError if response_body
      logger.info("Redirected to #{url}") if logger && logger.info?
      self.status = status
      self.location = url.gsub(/[\r\n]/, '')
      self.response_body = "<html><body>You are being <a href=\"#{CGI.escapeHTML(url)}\">redirected</a>.</body></html>"
    end
  end
end
