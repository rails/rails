require 'tempfile'

module Rack
  # Rack::Utils contains a grab-bag of useful methods for writing web
  # applications adopted from all kinds of Ruby libraries.

  module Utils
    # Performs URI escaping so that you can construct proper
    # query strings faster.  Use this rather than the cgi.rb
    # version since it's faster.  (Stolen from Camping).
    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+')
    end
    module_function :escape

    # Unescapes a URI escaped string. (Stolen from Camping).
    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      }
    end
    module_function :unescape

    # Stolen from Mongrel, with some small modifications:
    # Parses a query string by breaking it up at the '&'
    # and ';' characters.  You can also use this to parse
    # cookies by changing the characters used in the second
    # parameter (which defaults to '&;').

    def parse_query(qs, d = '&;')
      params = {}
      
      (qs || '').split(/[#{d}] */n).each do |p|
        k, v = unescape(p).split('=', 2)
        
        if cur = params[k]
          if cur.class == Array
            params[k] << v
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      end
      
      return params
    end
    module_function :parse_query
    
    def build_query(params)
      params.map { |k, v|
        if v.class == Array
          build_query(v.map { |x| [k, x] })
        else
          escape(k) + "=" + escape(v)
        end
      }.join("&")
    end
    module_function :build_query

    # Escape ampersands, brackets and quotes to their HTML/XML entities.
    def escape_html(string)
      string.to_s.gsub("&", "&amp;").
        gsub("<", "&lt;").
        gsub(">", "&gt;").
        gsub("'", "&#39;").
        gsub('"', "&quot;")
    end
    module_function :escape_html

    def select_best_encoding(available_encodings, accept_encoding)
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html

      expanded_accept_encoding =
        accept_encoding.map { |m, q|
          if m == "*"
            (available_encodings - accept_encoding.map { |m2, _| m2 }).map { |m2| [m2, q] }
          else
            [[m, q]]
          end
        }.inject([]) { |mem, list|
          mem + list
        }

      encoding_candidates = expanded_accept_encoding.sort_by { |_, q| -q }.map { |m, _| m }

      unless encoding_candidates.include?("identity")
        encoding_candidates.push("identity")
      end

      expanded_accept_encoding.find_all { |m, q|
        q == 0.0
      }.each { |m, _|
        encoding_candidates.delete(m)
      }

      return (encoding_candidates & available_encodings)[0]
    end
    module_function :select_best_encoding

    # The recommended manner in which to implement a contexting application
    # is to define a method #context in which a new Context is instantiated.
    #
    # As a Context is a glorified block, it is highly recommended that you
    # define the contextual block within the application's operational scope.
    # This would typically the application as you're place into Rack's stack.
    #
    #   class MyObject
    #     ...
    #     def context app
    #       Rack::Utils::Context.new app do |env|
    #         do_stuff
    #         response = app.call(env)
    #         do_more_stuff
    #       end
    #     end
    #     ...
    #   end
    #
    # mobj = MyObject.new
    # app = mobj.context other_app
    # Rack::Handler::Mongrel.new app
    class Context < Proc
      alias_method :old_inspect, :inspect
      attr_reader :for, :app
      def initialize app_f, app_r
        raise 'running context not provided' unless app_f
        raise 'running context does not respond to #context' unless app_f.respond_to? :context
        raise 'application context not provided' unless app_r
        raise 'application context does not respond to #call' unless app_r.respond_to? :call
        @for = app_f
        @app = app_r
      end
      def inspect
        "#{old_inspect} ==> #{@for.inspect} ==> #{@app.inspect}"
      end
      def context app_r
        raise 'new application context not provided' unless app_r
        raise 'new application context does not respond to #call' unless app_r.respond_to? :call
        @for.context app_r
      end
      def pretty_print pp
        pp.text old_inspect
        pp.nest 1 do
          pp.breakable
          pp.text '=for> '
          pp.pp @for
          pp.breakable
          pp.text '=app> '
          pp.pp @app
        end
      end
    end

    # A case-normalizing Hash, adjusting on [] and []=.
    class HeaderHash < Hash
      def initialize(hash={})
        hash.each { |k, v| self[k] = v }
      end

      def to_hash
        {}.replace(self)
      end

      def [](k)
        super capitalize(k)
      end

      def []=(k, v)
        super capitalize(k), v
      end

      def capitalize(k)
        k.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }
      end
    end

    # Every standard HTTP code mapped to the appropriate message.
    # Stolen from Mongrel.
    HTTP_STATUS_CODES = {
      100  => 'Continue',
      101  => 'Switching Protocols',
      200  => 'OK',
      201  => 'Created',
      202  => 'Accepted',
      203  => 'Non-Authoritative Information',
      204  => 'No Content',
      205  => 'Reset Content',
      206  => 'Partial Content',
      300  => 'Multiple Choices',
      301  => 'Moved Permanently',
      302  => 'Moved Temporarily',
      303  => 'See Other',
      304  => 'Not Modified',
      305  => 'Use Proxy',
      400  => 'Bad Request',
      401  => 'Unauthorized',
      402  => 'Payment Required',
      403  => 'Forbidden',
      404  => 'Not Found',
      405  => 'Method Not Allowed',
      406  => 'Not Acceptable',
      407  => 'Proxy Authentication Required',
      408  => 'Request Time-out',
      409  => 'Conflict',
      410  => 'Gone',
      411  => 'Length Required',
      412  => 'Precondition Failed',
      413  => 'Request Entity Too Large',
      414  => 'Request-URI Too Large',
      415  => 'Unsupported Media Type',
      500  => 'Internal Server Error',
      501  => 'Not Implemented',
      502  => 'Bad Gateway',
      503  => 'Service Unavailable',
      504  => 'Gateway Time-out',
      505  => 'HTTP Version not supported'
    }

    # A multipart form data parser, adapted from IOWA.
    #
    # Usually, Rack::Request#POST takes care of calling this.

    module Multipart
      EOL = "\r\n"

      def self.parse_multipart(env)
        unless env['CONTENT_TYPE'] =~
            %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n
          nil
        else
          boundary = "--#{$1}"

          params = {}
          buf = ""
          content_length = env['CONTENT_LENGTH'].to_i
          input = env['rack.input']

          boundary_size = boundary.size + EOL.size
          bufsize = 16384

          content_length -= boundary_size

          status = input.read(boundary_size)
          raise EOFError, "bad content body"  unless status == boundary + EOL

          rx = /(?:#{EOL})?#{Regexp.quote boundary}(#{EOL}|--)/

          loop {
            head = nil
            body = ''
            filename = content_type = name = nil

            until head && buf =~ rx
              if !head && i = buf.index("\r\n\r\n")
                head = buf.slice!(0, i+2) # First \r\n
                buf.slice!(0, 2)          # Second \r\n

                filename = head[/Content-Disposition:.* filename="?([^\";]*)"?/ni, 1]
                content_type = head[/Content-Type: (.*)\r\n/ni, 1]
                name = head[/Content-Disposition:.* name="?([^\";]*)"?/ni, 1]

                if filename
                  body = Tempfile.new("RackMultipart")
                  body.binmode  if body.respond_to?(:binmode)
                end

                next
              end

              # Save the read body part.
              if head && (boundary_size+4 < buf.size)
                body << buf.slice!(0, buf.size - (boundary_size+4))
              end

              c = input.read(bufsize < content_length ? bufsize : content_length)
              raise EOFError, "bad content body"  if c.nil? || c.empty?
              buf << c
              content_length -= c.size
            end

            # Save the rest.
            if i = buf.index(rx)
              body << buf.slice!(0, i)
              buf.slice!(0, boundary_size+2)

              content_length = -1  if $1 == "--"
            end

            if filename
              body.rewind
              data = {:filename => filename, :type => content_type,
                      :name => name, :tempfile => body, :head => head}
            else
              data = body
            end

            if name
              if name =~ /\[\]\z/
                params[name] ||= []
                params[name] << data
              else
                params[name] = data
              end
            end

            break  if buf.empty? || content_length == -1
          }

          params
        end
      end
    end
  end
end
