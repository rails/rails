class CGI #:nodoc:
  # Add @request.env['RAW_POST_DATA'] for the vegans.
  module QueryExtension
    # Initialize the data from the query.
    #
    # Handles multipart forms (in particular, forms that involve file uploads).
    # Reads query parameters in the @params field, and cookies into @cookies.
    def initialize_query()
      if boundary = multipart_form_boundary
        @multipart = true
        @params = read_multipart(boundary, Integer(env_table['CONTENT_LENGTH']))
      else
        @multipart = false
        @params = CGI::parse(read_query_params)
      end
      
      @cookies = CGI::Cookie::parse((env_table['HTTP_COOKIE'] or env_table['COOKIE']))
    end

    private
      MULTIPART_FORM_BOUNDARY_RE = %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n #"

      def multipart_form_boundary        
        if env_table['REQUEST_METHOD'] == 'POST'
          MULTIPART_FORM_BOUNDARY_RE.match(env_table['CONTENT_TYPE']).to_a.pop
        end
      end

      def read_query_params
        case env_table['REQUEST_METHOD']
          when 'GET', 'HEAD'
            if defined? MOD_RUBY              
              Apache::request.args or ''
            else
              env_table['QUERY_STRING'] or ''
            end
          when 'POST'
            stdinput.binmode if stdinput.respond_to?(:binmode)
            content = stdinput.read(Integer(env_table['CONTENT_LENGTH'])) or ''
            env_table['RAW_POST_DATA'] = content.freeze
          else
            read_from_cmdline
          end
      end
  end # module QueryExtension
end
