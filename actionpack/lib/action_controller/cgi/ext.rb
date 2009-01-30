require 'action_controller/cgi/ext/stdinput'
require 'action_controller/cgi/ext/query_extension'
require 'action_controller/cgi/ext/cookie'

class CGI #:nodoc:
  include ActionController::CgiExt::Stdinput

  class << self
    alias :escapeHTML_fail_on_nil :escapeHTML

    def escapeHTML(string)
      escapeHTML_fail_on_nil(string) unless string.nil?
    end
  end
end
