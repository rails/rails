class CGI #:nodoc:
  module QueryExtension
    # Initialize the data from the query.
    #
    # Handles multipart forms (in particular, forms that involve file uploads).
    # Reads query parameters in the @params field, and cookies into @cookies.
    def initialize_query
      @cookies = CGI::Cookie::parse(env_table['HTTP_COOKIE'] || env_table['COOKIE'])

      # Fix some strange request environments.
      if method = env_table['REQUEST_METHOD']
        method = method.to_s.downcase.intern
      else
        method = :get
      end

      # POST assumes missing Content-Type is application/x-www-form-urlencoded.
      content_type = env_table['CONTENT_TYPE']
      if content_type.blank? && method == :post
        content_type = 'application/x-www-form-urlencoded'
      end

      # Force content length to zero if missing.
      content_length = env_table['CONTENT_LENGTH'].to_i

      # Set multipart to false by default.
      @multipart = false

      # POST and PUT may have params in entity body. If content type is
      # missing for POST, assume urlencoded. If content type is missing
      # for PUT, don't assume anything and don't parse the parameters:
      # it's likely binary data.
      #
      # The other HTTP methods have their params in the query string.
      if method == :post || method == :put
        if boundary = extract_multipart_form_boundary(content_type)
          @multipart = true
          @params = read_multipart(boundary, content_length)
        elsif content_type.blank? || content_type !~ %r{application/x-www-form-urlencoded}i
          read_params(method, content_length)
          @params = {}
        end
      end

      @params ||= CGI.parse(read_params(method, content_length))
    end

    private
      unless defined?(MULTIPART_FORM_BOUNDARY_RE)
        MULTIPART_FORM_BOUNDARY_RE = %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n #"
      end

      def extract_multipart_form_boundary(content_type)
        MULTIPART_FORM_BOUNDARY_RE.match(content_type).to_a.pop
      end

      if defined? MOD_RUBY
        def read_query
          Apache::request.args || ''
        end
      else
        def read_query
          # fixes CGI querystring parsing for lighttpd
          env_qs = env_table['QUERY_STRING']
          if env_qs.blank? && !(uri = env_table['REQUEST_URI']).blank?
            uri.split('?', 2)[1] || ''
          else
            env_qs
          end
        end
      end

      def read_body(content_length)
        stdinput.binmode if stdinput.respond_to?(:binmode)
        content = stdinput.read(content_length) || ''
        # Fix for Safari Ajax postings that always append \000
        content.chop! if content[-1] == 0
        content.gsub!(/&_=$/, '')
        env_table['RAW_POST_DATA'] = content.freeze
      end

      def read_params(method, content_length)
        case method
          when :get
            read_query
          when :post, :put
            read_body(content_length)
          when :cmd
            read_from_cmdline
          else # :head, :delete, :options, :trace, :connect
            read_query
        end
      end
  end # module QueryExtension
end
