require 'action_controller/cgi_ext/parameters'
require 'action_controller/cgi_ext/query_extension'
require 'action_controller/cgi_ext/cookie'
require 'action_controller/cgi_ext/session'

class CGI #:nodoc:
  include ActionController::CgiExt::Parameters
end
