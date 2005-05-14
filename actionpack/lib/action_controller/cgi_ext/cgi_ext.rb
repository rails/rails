require 'cgi'
require 'cgi/session'
require 'cgi/session/pstore'
require 'action_controller/cgi_ext/cgi_methods'

# Wrapper around the CGIMethods that have been secluded to allow testing without 
# an instantiated CGI object
class CGI #:nodoc:
  class << self
    alias :escapeHTML_fail_on_nil :escapeHTML

    def escapeHTML(string)
      escapeHTML_fail_on_nil(string) unless string.nil?
    end
  end
  
  # Returns a parameter hash including values from both the request (POST/GET)
  # and the query string with the latter taking precedence.
  def parameters
    request_parameters.update(query_parameters)
  end

  def query_parameters
    CGIMethods.parse_query_parameters(query_string)
  end

  def request_parameters
    CGIMethods.parse_request_parameters(params, env_table)
  end

  def redirect(where)
     header({ 
       "Status" => "302 Moved", 
       "location" => "#{where}"
    })
  end
  
  def session(parameters = nil)
    parameters = {} if parameters.nil?
    parameters['database_manager'] = CGI::Session::PStore
    CGI::Session.new(self, parameters)
  end
end
