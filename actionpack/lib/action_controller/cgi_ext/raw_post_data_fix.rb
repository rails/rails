class CGI #:nodoc:
  # Add @request.env['RAW_POST_DATA'] for the vegans.
  module QueryExtension
    # Initialize the data from the query.
    #
    # Handles multipart forms (in particular, forms that involve file uploads).
    # Reads query parameters in the @params field, and cookies into @cookies.
    def initialize_query()
      @cookies = CGI::Cookie::parse((env_table['HTTP_COOKIE'] || env_table['COOKIE']))

      if boundary = multipart_form_boundary
        @multipart = true
        @params = read_multipart(boundary, Integer(env_table['CONTENT_LENGTH']))
      else
        @multipart = false
        @params = CGI::parse(read_query_params || "")
      end
    end

    private
      unless defined?(MULTIPART_FORM_BOUNDARY_RE)
        MULTIPART_FORM_BOUNDARY_RE = %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n #"
      end

      def multipart_form_boundary        
        if env_table['REQUEST_METHOD'] == 'POST'
          MULTIPART_FORM_BOUNDARY_RE.match(env_table['CONTENT_TYPE']).to_a.pop
        end
      end

      def read_params_from_query
        if defined? MOD_RUBY
          Apache::request.args || ''
        else
          # fixes CGI querystring parsing for POSTs
          if env_table['QUERY_STRING'].blank? && !env_table['REQUEST_URI'].blank?
            env_table['QUERY_STRING'] = env_table['REQUEST_URI'].split('?', 2)[1] || ''
          end
          env_table['QUERY_STRING']
        end
      end

      def read_params_from_post
        stdinput.binmode if stdinput.respond_to?(:binmode)
        content = stdinput.read(Integer(env_table['CONTENT_LENGTH'])) || ''
        env_table['RAW_POST_DATA'] = content.split("&_").first.to_s.freeze # &_ is a fix for Safari Ajax postings that always append \000
      end

      def read_query_params
        case env_table['REQUEST_METHOD'].to_s.upcase
          when 'CMD'
            read_from_cmdline
          when 'POST', 'PUT'
            read_params_from_post
          else # when 'GET', 'HEAD', 'DELETE', 'OPTIONS'
            read_params_from_query
        end
      end
  end # module QueryExtension
end
