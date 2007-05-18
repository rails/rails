require 'cgi'

class CGI #:nodoc:
  module QueryExtension
    # Remove the old initialize_query method before redefining it.
    remove_method :initialize_query

    # Neuter CGI parameter parsing.
    def initialize_query
      # Fix some strange request environments.
      env_table['REQUEST_METHOD'] ||= 'GET'

      # POST assumes missing Content-Type is application/x-www-form-urlencoded.
      if env_table['CONTENT_TYPE'].blank? && env_table['REQUEST_METHOD'] == 'POST'
        env_table['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
      end

      @cookies = CGI::Cookie::parse(env_table['HTTP_COOKIE'] || env_table['COOKIE'])
      @params = {}
    end
  end
end
