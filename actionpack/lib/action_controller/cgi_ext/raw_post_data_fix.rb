class CGI #:nodoc:
  # Add @request.env['RAW_POST_DATA'] for the vegans.
  module QueryExtension
    # Initialize the data from the query.
    #
    # Handles multipart forms (in particular, forms that involve file uploads).
    # Reads query parameters in the @params field, and cookies into @cookies.
    def initialize_query()
      @cookies = CGI::Cookie::parse(env_table['HTTP_COOKIE'] || env_table['COOKIE'])

      #fix some strange request environments
      if method = env_table['REQUEST_METHOD']
        method = method.to_s.downcase.intern
      else
        method = :get
      end

      if method == :post && (boundary = multipart_form_boundary)
        @multipart = true
        @params = read_multipart(boundary, Integer(env_table['CONTENT_LENGTH']))
      else
        @multipart = false
        @params = CGI::parse(read_query_params(method) || "")
      end
    end

    private
      unless defined?(MULTIPART_FORM_BOUNDARY_RE)
        MULTIPART_FORM_BOUNDARY_RE = %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n #"
      end

      def multipart_form_boundary
        MULTIPART_FORM_BOUNDARY_RE.match(env_table['CONTENT_TYPE']).to_a.pop
      end

      if defined? MOD_RUBY
        def read_params_from_query
          Apache::request.args || ''
        end
      else
        def read_params_from_query
          # fixes CGI querystring parsing for lighttpd
          env_qs = env_table['QUERY_STRING']
          if env_qs.blank? && !(uri = env_table['REQUEST_URI']).blank?
            uri.split('?', 2)[1] || ''
          else
            env_qs
          end
        end
      end

      def read_params_from_post
        stdinput.binmode if stdinput.respond_to?(:binmode)
        content = stdinput.read(Integer(env_table['CONTENT_LENGTH'])) || ''
        # fix for Safari Ajax postings that always append \000
        content.chop! if content[-1] == 0
        content.gsub! /&_=$/, ''
        env_table['RAW_POST_DATA'] = content.freeze
      end

      def read_query_params(method)
        case method
          when :get
            read_params_from_query
          when :post, :put
            read_params_from_post
          when :cmd
            read_from_cmdline
          else # when :head, :delete, :options
            read_params_from_query
        end
      end
  end # module QueryExtension
end
