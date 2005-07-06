require File.dirname(__FILE__) + '/cgi/escape_skipping_slashes'

class CGI #:nodoc:
  extend(ActiveSupport::CoreExtensions::CGI::EscapeSkippingSlashes)
end
