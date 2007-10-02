require 'active_support/core_ext/cgi/escape_skipping_slashes'

class CGI #:nodoc:
  extend ActiveSupport::CoreExtensions::CGI::EscapeSkippingSlashes
end
