require 'action_controller/cgi_ext/stdinput'
require 'action_controller/cgi_ext/query_extension'
require 'action_controller/cgi_ext/cookie'

class CGI #:nodoc:
  include ActionController::CgiExt::Stdinput

  class << self
    alias :escapeHTML_fail_on_nil :escapeHTML

    def escapeHTML(string)
      escapeHTML_fail_on_nil(string) unless string.nil?
    end
  end
end
